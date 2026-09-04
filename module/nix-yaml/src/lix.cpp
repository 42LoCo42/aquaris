#include <lix/libexpr/primops.hh>
#include <yaml-cpp/yaml.h>

using namespace nix;

static bool tryBool(const char* scalar, Value* v) {
	if(strcmp(scalar, "true") == 0) {
		*v = Value(NewValueAs::boolean, true);
		return true;
	}

	if(strcmp(scalar, "false") == 0) {
		*v = Value(NewValueAs::boolean, false);
		return true;
	}

	return false;
}

static bool tryInt(const char* scalar, Value* v) {
	char* end = NULL;
	long  val = strtol(scalar, &end, 10);

	if(*end != 0) return false;

	*v = Value(NewValueAs::integer, val);
	return true;
}

static bool tryDouble(const char* scalar, Value* v) {
	char*  end = NULL;
	double val = strtod(scalar, &end);

	if(*end != 0) return false;

	*v = Value(NewValueAs::floating, val);
	return true;
}

static bool tryString(const char* scalar, Value* v) {
	*v = Value(NewValueAs::string, scalar);
	return true;
}

static void yaml2nix(EvalState& state, YAML::Node node, Value* v) {
	switch(node.Type()) {
	case YAML::NodeType::Undefined:
	case YAML::NodeType::Null:
		v->mkNull();
		break;

	case YAML::NodeType::Scalar: {
		const char* scalar = node.Scalar().data();
		tryBool(scalar, v)          //
			|| tryInt(scalar, v)    //
			|| tryDouble(scalar, v) //
			|| tryString(scalar, v);
	} break;

	case YAML::NodeType::Sequence: {
		auto list = state.ctx.mem.newList(node.size());

		for(size_t i = 0; i < node.size(); i++) {
			const auto& sub = node[i];
			yaml2nix(state, sub, &list->elems[i]);
		}

		*v = Value(NewValueAs::list, list);
	} break;

	case YAML::NodeType::Map: {
		auto attrs = state.ctx.buildBindings(node.size());

		for(const auto& sub : node) {
			auto  sym = state.ctx.symbols.create(sub.first.Scalar().data());
			auto& val = attrs.alloc(sym);
			yaml2nix(state, sub.second, &val);
		}

		*v = Value(NewValueAs::attrs, attrs);
	} break;
	}
}

void fromYAML(EvalState& state, Value** args, Value& v) {
	try {
		auto yaml = state.forceStringNoCtx(*args[0], noPos, "");
		auto docs = YAML::LoadAll(std::string(yaml));

		if(docs.size() == 1) {
			yaml2nix(state, docs[0], &v);
		} else {
			auto list = state.ctx.mem.newList(docs.size());

			for(size_t i = 0; i < docs.size(); i++) {
				yaml2nix(state, docs[i], &list->elems[i]);
			}

			v = Value(NewValueAs::list_t(), list);
		}
	} catch(YAML::ParserException& e) {
		throw Error(e.msg); //
	}
}

extern "C" void nix_plugin_entry(void) {
	PluginPrimOps::add({
		.name                = "fromYAML",
		.args                = {"yaml"},
		.arity               = 1,
		.doc                 = "Converts a YAML string to a Nix value.",
		.fun                 = fromYAML,
		.experimentalFeature = {},
	});
}
