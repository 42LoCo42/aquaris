{
  inputs.aquaris.url = "github:42loco42/aquaris";
  outputs = { self, aquaris, ... }: aquaris.lib.aquarisSystems self;
}
