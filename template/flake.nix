{
  inputs.aquaris.url = "github:42loco42/aquaris";
  outputs = { aquaris, ... }: aquaris.lib.setup;
}
