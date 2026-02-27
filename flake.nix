{
  description = "Kernel development environments";

  inputs = {
    systems.url = "github:nix-systems/default-linux";

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    klee = {
      url = "github:uchi-zero/klee/dev/v3.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      fenix,
      flake-utils,
      klee,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ klee.overlays.default ];
        };

        # A set of scripts to simplify kernel development.
        kernelDevTools = pkgs.callPackage ./tools.nix {
          flakeSelf = self;
        };

        linuxCommonDependencies =
          [
            kernelDevTools
          ]
          ++ (with pkgs; [
            bc
            bison
            cpio
            elfutils
            flex
            gmp
            gnumake
            gllvm
            kmod
            libmpc
            mpfr
            nettools
            openssl
            pahole
            perl
            python3Minimal
            rsync
            ubootTools
            zlib
            zstd

            # For make menuconfig
            ncurses

            # For make gtags
            global

            # For git send-email 🫠
            gitFull
          ]);

        rust-analyzer = fenix.packages."${system}".rust-analyzer;

        linuxRustDependencies =
          { clang, rustVersion }:
          let
            rustc = rust-overlay.packages."${system}"."${rustVersion}".override {
              extensions = [
                "rust-src"
                "rustfmt"
                "clippy"
              ];
            };

            rustPlatform = pkgs.makeRustPlatform {
              cargo = rustc;
              rustc = rustc;
            };

            bindgenUnwrapped = pkgs.callPackage ./bindgen/0.65.1.nix {
              inherit rustPlatform clang;
            };

            bindgen = pkgs.rust-bindgen.override {
              rust-bindgen-unwrapped = bindgenUnwrapped;
            };
          in
          [
            bindgen
            rust-analyzer
            rustc
          ];

        mkGccShell =
          { gccVersion }:
          pkgs.mkShell {
            packages = linuxCommonDependencies ++ [ pkgs."gcc${gccVersion}" ];

            # Disable all automatically applied hardening. The Linux
            # kernel will take care of itself.
            NIX_HARDENING_ENABLE = "";
          };

        mkClangShell =
          { rustcVersion }:
          let
            llvmPackages = pkgs.llvmPackages_klee;
          in
          pkgs.mkShell {
            packages =
              [
                pkgs.klee
              ]
              ++ (with llvmPackages; [
                bintools
                clang
                llvm
              ])
              ++ (linuxRustDependencies {
                inherit (llvmPackages) clang;
                rustVersion = "rust_${rustcVersion}";
              })
              ++ linuxCommonDependencies;

            # To force LLVM build mode. This should create less problems
            # with Rust interop.
            LLVM = "1";

            # Disable all automatically applied hardening. The Linux
            # kernel will take care of itself.
            NIX_HARDENING_ENABLE = "";
          };
      in
      {
        packages = {
          inherit kernelDevTools;
          default = kernelDevTools;
        };

        devShells = {
          default = self.devShells."${system}".linux_6_12;

          linux_6_6 = mkClangShell {
            rustcVersion = "1_78_0";
          };
          linux_6_6_gcc = mkGccShell { gccVersion = "14"; };

          linux_6_11 = mkClangShell {
            rustcVersion = "1_78_0";
          };
          linux_6_11_gcc = mkGccShell { gccVersion = "14"; };

          linux_6_12 = mkClangShell {
            rustcVersion = "1_82_0";
          };
          linux_6_12_gcc = mkGccShell { gccVersion = "14"; };
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
