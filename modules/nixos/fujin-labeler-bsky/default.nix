{
    # Snowfall Lib provides a customized `lib` instance with access to your flake's library
    # as well as the libraries available from your flake's inputs.
    lib,
    # An instance of `pkgs` with your overlays and packages applied is also available.
    pkgs,
    # You also have access to your flake's inputs.
    inputs,

    # Additional metadata is provided by Snowfall Lib.
    namespace, # The namespace used for your flake, defaulting to "internal" if not set.
    system, # The system architecture for this host (eg. `x86_64-linux`).
    target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
    format, # A normalized name for the system target (eg. `iso`).
    virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
    systems, # An attribute map of your defined hosts.

    # All other arguments come from the module system.
    config,
    ...
}:
let
    inherit (builtins) toString;
    inherit (lib) types mkIf mkOption mkDefault;
    inherit (lib) optional optionals optionalAttrs optionalString;
    cfg = config.services.fujin-bsky-labeler;
in {
    options.services.fujin-bsky-labeler = {
        enable =
            lib.mkEnableOption "A labeler for Fujin"; 

        host = mkOption {
            type = types.str;
            description = "The public host name to serve.";
            example = "fujinlabeler.fujocoded.com/";
        };

        port = mkOption {
            type = types.port;
            default = 4107;
            description = "The port the labeler should listen on.";
        };

        metricsPort = mkOption {
            type = types.port;
            default = 4108;
            description = "The port for the labeler metrics.";
        };

        signingKeyFile = mkOption {
            ##
            # DO NOT USE types.path! It pulls the file into the Nix Store and
            # this should stay a secret no one but us knows.
            ##
            type = types.str;
            description = ''
              Path to a file containing the private signing key for the labeler.
            '';
        };

        stateDir = mkOption {
            type = types.str;
            default = "/var/lib/fujin-bsky-labeler";
            description = ''
                Where the database and cursor will be saved.
            '';
        };

        user = mkOption {
            type = types.str;
            default = "fujin-bsky-labeler";
            description = "User under which fujin-bsky-labeler is ran.";
        };

        group = mkOption {
            type = types.str;
            default = "fujin-bsky-labeler";
            description = "Group under which fujin-bsky-labeler is ran.";
        };

        package = mkOption {
            type = types.package;
            default = pkgs.${namespace}.fujin-bsky-labeler;
            description = "The labeler package to run";
        };
    };
  
    config = mkIf cfg.enable {
        users = {
            users = optionalAttrs (cfg.user == "fujin-bsky-labeler") {
                fujin-bsky-labeler = {
                    group = cfg.group;
                    home = cfg.stateDir;
                    isSystemUser = true;
                };
            };

            groups =
                optionalAttrs (cfg.group == "fujin-bsky-labeler") { fujin-bsky-labeler = { }; };
        };

        systemd.services.fujin-bsky-labeler = {
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = cfg.stateDir;
                Restart = "always";
                RestartSec = 20;
            };

            environment = {
                PORT = builtins.toString cfg.port;
                METRICS_PORT = builtins.toString cfg.metricsPort;
                CURSOR_FILE_PATH = "${cfg.stateDir}/cursor.txt";
                DB_PATH =  "${cfg.stateDir}/labels.db";
            };

            # this is where we can write a bash script to do everything we need 
            script = ''
                if ! test -f "${cfg.signingKeyFile}"; then
                  echo "Your signing key file is missing!"
                  exit 1
                fi

                export SIGNING_KEY="$(cat ${cfg.signingKeyFile})"
                exec ${cfg.package}/bin/fujin-bsky-labeler
            '';
        };

        services.nginx.virtualHosts."${cfg.host}" = {
            enableACME = true;
            forceSSL = true;
        
            locations."/" = {
                proxyWebsockets = true;
                proxyPass = "http://127.0.0.1:${toString cfg.port}";
            };
        }; 
    };
}
