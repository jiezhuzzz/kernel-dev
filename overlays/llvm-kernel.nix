# Overlay to customize llvmPackages_klee for kernel development
# Suppresses noisy warnings during kernel compilation with LLVM/Clang
final: prev: {
  llvmPackages_klee = prev.llvmPackages_klee // {
    stdenv = prev.llvmPackages_klee.stdenv // {
      mkDerivation =
        attrs:
        (prev.llvmPackages_klee.stdenv.mkDerivation attrs).overrideAttrs (this: {
          env = (this.env or { }) // {
            # Fix `--target` spam.
            NIX_CC_WRAPPER_SUPPRESS_TARGET_WARNING = 1;
            # Fix `-nostdinc` warnings.
            NIX_CFLAGS_COMPILE = prev.lib.concatStringsSep " " [
              (this.env.NIX_CFLAGS_COMPILE or "")
              "-Wno-unused-command-line-argument"
            ];
          };
        });
    };
  };
}
