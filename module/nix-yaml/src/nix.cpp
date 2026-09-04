#include <nix/expr/primops.hh>
#include <yaml-cpp/yaml.h>

using namespace nix;

static bool tryBool(const char* scalar, Value* v) {
	if(strcmp(scalar, "true") == 0) {
		v->mkBool(true);
		return true;
	}

	if(strcmp(scalar, "false") == 0) {
		v->mkBool(false);
		return true;
	}

	return false;
}

static bool tryInt(const char* scalar, Value* v) {
	char* end = NULL;
	long  val = strtol(scalar, &end, 10);

	if(*end != 0) return false;

	v->mkInt(val);
	return true;
}

static bool tryDouble(const char* scalar, Value* v) {
	char*  end = NULL;
	double val = strtod(scalar, &end);

	if(*end != 0) return false;

	v->mkFloat(val);
	return true;
}

static bool tryString(EvalMemory& mem, const char* scalar, Value* v) {
	v->mkString(scalar, mem);
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
			|| tryString(state.mem, scalar, v);
	} break;

	case YAML::NodeType::Sequence: {
		auto list = state.buildList(node.size());

		for(const auto& [i, sub] : enumerate(node)) {
			auto val = state.allocValue();
			yaml2nix(state, sub, val);
			list.elems[i] = val;
		}

		v->mkList(list);
	} break;

	case YAML::NodeType::Map: {
		auto attrs = state.buildBindings(node.size());

		for(const auto& sub : node) {
			auto  sym = state.symbols.create(sub.first.Scalar().data());
			auto& val = attrs.alloc(sym);
			yaml2nix(state, sub.second, &val);
		}

		v->mkAttrs(attrs);
	} break;
	}
}

void fromYAML(EvalState& state, const PosIdx, Value** args, Value& v) {
	try {
		auto yaml = state.forceStringNoCtx(*args[0], noPos, "");
		auto docs = YAML::LoadAll(std::string(yaml));

		if(docs.size() == 1) {
			yaml2nix(state, docs[0], &v);
		} else {
			auto list = state.buildList(docs.size());

			for(const auto& [i, val] : enumerate(list)) {
				yaml2nix(state, docs[i], (val = state.allocValue()));
			}

			v.mkList(list);
		}
	} catch(YAML::ParserException&) {
		auto e = std::current_exception();
		v.mkFailed(e, nullptr);
	}
}

extern "C" void nix_plugin_entry(void) {
	RegisterPrimOp({
		.name                = "fromYAML",
		.args                = {"yaml"},
		.arity               = 1,
		.doc                 = "Converts a YAML string to a Nix value.",
		.impl                = fromYAML,
		.experimentalFeature = {},
	});
}
