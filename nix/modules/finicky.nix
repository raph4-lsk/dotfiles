{ pkgs, ... }:
{
  home.packages = [ pkgs.finicky ];

  home.file.".finicky.js".text = ''
    export default {
      defaultBrowser: "Google Chrome",
      handlers: [
        { match: "*github.com/*", browser: "Microsoft Edge" }
      ]
    };
  '';
}
