# TODO:
# - why do we need to patch the compiler (cmxs etc)?
#   - using dune 3.9.3 does not change it.
# - import ocaml-variant files
# - ppxlib: import astlib dir
final: prev:
let
  fetchFromGitHub = prev.fetchFromGitHub;
  buildDunePackage = final.ocamlPackages.buildDunePackage;
  janePackage = { name, rev, hash, deps ? [ ] }:
    buildDunePackage {
      version = "v0.18~preview.130.26+1192";
      pname = name;
      src = fetchFromGitHub {
        inherit rev hash;
        owner = "janestreet";
        repo = name;
      };
      propagatedBuildInputs = deps;
    };
  init =
    let
      env = prev.ocaml-ng.ocamlPackages_5_2;
      menhirLib = env.menhirLib.override { version = "20231231"; };
      menhirSdk = env.menhirSdk.override { inherit menhirLib; };
      menhir = env.menhir.override {
        inherit menhirLib menhirSdk;
      };
    in
    {
      inherit (env) ocaml;
      inherit menhir;
      dune = env.dune_3;
    };
in
{
  ocamlPackages = prev.ocamlPackages.overrideScope
    (ofinal: oprev:
      {
        ocaml = oprev.ocaml.overrideAttrs (attrs: {
          src =
            fetchFromGitHub {
              owner = "ocaml-flambda";
              repo = "flambda-backend";
              tag = "5.2.0minus-8";
              hash = "sha256-kO6Sp9WukaDS8eNmssXlnBzJ0yXxZVhUK4MwdLpyXVE=";
            };
          nativeBuildInputs = [
            final.autoconf
            final.rsync
            init.ocaml
            init.menhir
            init.dune
          ];
          version = "5.2.0minus-8";
          postPatch = ''
            substituteInPlace \
              Makefile.common-jst \
              --replace-fail which "command -v"
            substituteInPlace \
              ocamltest/run_stubs.c \
              --replace-fail 'ifndef CAML_RUNTIME_5' 'if 0'
            substituteInPlace \
              otherlibs/runtime_events/dune \
              --replace-fail '(runtime_events.cmxs' ';'
            substituteInPlace \
              otherlibs/str/dune \
              --replace-fail '(str.cmxs' ';'
            substituteInPlace \
              otherlibs/unix/dune \
              --replace-fail '(unix.cmxs' ';'
          '';
          preConfigure = ''
            autoconf
          '' + attrs.preConfigure;
          configureFlags =
            attrs.configureFlags ++
            [
              "--enable-runtime5"
              "--enable-middle-end=flambda2"
              "--enable-poll-insertion"
              "--disable-naked-pointers"
              "--with-dune=${init.dune}/bin/dune"
            ];
          buildFlags = [ ];
          doCheck = false;
          installTargets = [ "install" ];
        });
        ocaml-compiler-libs = oprev.ocaml-compiler-libs.overrideAttrs {
          patches = ./ocaml-compiler-libs/read_cma.patch;
          propagatedBuildInputs = [ ];
        };
        ocamlbuild = oprev.ocamlbuild.overrideAttrs {
          patches = ./ocamlbuild/flambda2.patch;
        };
        topkg = oprev.topkg.overrideAttrs {
          patches = ./topkg/topkg_string.patch;
        };
        merlin = buildDunePackage {
          pname = "merlin";
          version = "5.2.1-502+jst";
          src = fetchFromGitHub {
            owner = "janestreet";
            repo = "merlin-jst";
            rev = "a1ef620d3154709b41355452fde6792db289b6ce";
            hash = "sha256-NLGbs12PJ4qFVg2Dwgs+CXLMCQq6j8NOTTf/bJLkpog=";
          };
          propagatedBuildInputs = with ofinal;
          [
            merlin-lib
            yojson
          ];
        };
        merlin-lib = buildDunePackage {
          pname = "merlin-lib";
          inherit(ofinal.merlin) version src;
          propagatedBuildInputs = with ofinal;
          [
            csexp
          ];
        };
        ppx_compare =
          janePackage {
            name = "ppx_compare";
            rev = "508ed84d50154914529ed6081c40be646ee669ae";
            hash = "sha256-ptg535ARk+F5hKiRsCcv1iPfERy9CQv1IMyNycY6AfQ=";
            deps = with ofinal; [ ppxlib ];
          };
        sexplib0 = janePackage {
          name = "sexplib0";
          rev = "c834895ef14f43e285c5cd37e66364dec260dc2a";
          hash = "sha256-wqAeUBy1Ri9YIdHbBNu8VYivQfAb4XtnMzFjuZvMcVk=";
          deps = with ofinal; [ basement ];
        };
        ppx_sexp_conv = janePackage {
          name = "ppx_sexp_conv";
          rev = "bedab20effc91091c09c8b7a1c0199435d116ac5";
          hash = "sha256-DKNwrGsRAbAZwl97T2PxU82cCtYiWO+VprHXAzdtOLs=";
          deps = with ofinal; [ ppxlib basement ];
        };
        basement = janePackage {
          name = "basement";
          rev = "ac97a5d35c3c58b1b5be7732a919c15796d2c4db";
          hash = "sha256-YOtvPsjIs+lHkRPkgSAICGPrVnq/ZicO6nEez/VUrhA=";
        };
        ppxlib = buildDunePackage {
          pname = "ppxlib";
          version = "0.33.0+jst";
          postPatch = ''
            rm -rf ast astlib stdppx traverse_builtins
          '';
          patches = [
            ./ppxlib/ppxlib+metaquot+ppxlib_metaquot.ml.patch
            ./ppxlib/ppxlib+runner_as_ppx+ppxlib_runner_as_ppx.ml.patch
            ./ppxlib/ppxlib+src+ast_builder.ml.patch
            ./ppxlib/ppxlib+src+ast_builder.mli.patch
            ./ppxlib/ppxlib+src+ast_builder_intf.ml.patch
            ./ppxlib/ppxlib+src+ast_pattern.ml.patch
            ./ppxlib/ppxlib+src+ast_pattern.mli.patch
            ./ppxlib/ppxlib+src+ast_traverse.ml.patch
            ./ppxlib/ppxlib+src+attribute.ml.patch
            ./ppxlib/ppxlib+src+attribute.mli.patch
            ./ppxlib/ppxlib+src+cinaps+ppxlib_cinaps_helpers.ml.patch
            ./ppxlib/ppxlib+src+code_matcher.ml.patch
            ./ppxlib/ppxlib+src+code_matcher.mli.patch
            ./ppxlib/ppxlib+src+common.ml.patch
            ./ppxlib/ppxlib+src+common.mli.patch
            ./ppxlib/ppxlib+src+context_free.ml.patch
            ./ppxlib/ppxlib+src+context_free.mli.patch
            ./ppxlib/ppxlib+src+deriving.ml.patch
            ./ppxlib/ppxlib+src+deriving.mli.patch
            ./ppxlib/ppxlib+src+driver.ml.patch
            ./ppxlib/ppxlib+src+driver.mli.patch
            ./ppxlib/ppxlib+src+gen+gen_ast_builder.ml.patch
            ./ppxlib/ppxlib+src+gen+gen_ast_pattern.ml.patch
            ./ppxlib/ppxlib+src+gen+import.ml.patch
            ./ppxlib/ppxlib+src+ignore_unused_warning.ml.patch
            ./ppxlib/ppxlib+src+location.ml.patch
            ./ppxlib/ppxlib+src+location.mli.patch
            ./ppxlib/ppxlib+src+name.ml.patch
            ./ppxlib/ppxlib+src+utils.ml.patch
            ./ppxlib/ppxlib+src+utils.mli.patch
            ./ppxlib/ppxlib+traverse+ppxlib_traverse.ml.patch
            ./ppxlib/dune.patch
            ./ppxlib/location_check.ml.patch
          ];
          src = fetchFromGitHub {
            owner = "ocaml-ppx";
            repo = "ppxlib";
            rev = "1f788de67fd04d7e608376ac26ee57deeeb93fdd";
            hash = "sha256-gryEqVTmTMnTYb1bPlGdWhCpoDUyrs4O3zEYkaau2rw=";
          };
          propagatedBuildInputs =
            with ofinal;
            [
              ppxlib_ast
              stdlib-shims
              sexplib0
              ocaml-compiler-libs
              ppx_derivers
              ppxlib_jane
            ];
        };
        ppxlib_ast = buildDunePackage {
          pname = "ppxlib_ast";
          inherit (ofinal.ppxlib) src version;
          postPatch = ''
            set -o pipefail

            rm -rf bench dev doc examples metaquot metaquot_lifters old_rtd_doc print-diff runner runner_as_ppx src test traverse ppxlib*.opam

            asts_to_remove="402 403 404 405 406 407 408 409 410 411 412 413"
            prev_version=

            for version in $asts_to_remove; do
              rm astlib/ast_''${version}.ml
              if [ -n "$prev_version" ]; then
                rm astlib/migrate_''${version}_''${prev_version}.ml
                rm astlib/migrate_''${prev_version}_''${version}.ml
              fi
              prev_version=$version
            done

            rm astlib/ast_501.ml
            rm astlib/migrate_413_414.ml
            rm astlib/migrate_414_413.ml
            rm astlib/migrate_500_501.ml
            rm astlib/migrate_501_500.ml
          '';
          patches = [
            ./ppxlib_ast/ppxlib+ast+ast.ml.patch
            ./ppxlib_ast/ppxlib+ast+ast_helper_lite.ml.patch
            ./ppxlib_ast/ppxlib+ast+ast_helper_lite.mli.patch
            ./ppxlib_ast/ppxlib+ast+location_error.ml.patch
            ./ppxlib_ast/ppxlib+ast+location_error.mli.patch
            ./ppxlib_ast/ppxlib+ast+supported_version+supported_version.ml.patch
            ./ppxlib_ast/ppxlib+ast+versions.ml.patch
            ./ppxlib_ast/ppxlib+ast+versions.mli.patch
            ./ppxlib_ast/ppxlib+astlib+ast_414.ml.patch
            ./ppxlib_ast/ppxlib+astlib+ast_500.ml.patch
            ./ppxlib_ast/ppxlib+astlib+ast_999.ml.patch
            ./ppxlib_ast/ppxlib+astlib+ast_metadata.mli.patch
            ./ppxlib_ast/ppxlib+astlib+astlib.ml.patch
            ./ppxlib_ast/ppxlib+astlib+cinaps+astlib_cinaps_helpers.ml.patch
            ./ppxlib_ast/ppxlib+astlib+config+gen.ml.patch
            ./ppxlib_ast/ppxlib+astlib+migrate_500_999.ml.patch
            ./ppxlib_ast/ppxlib+astlib+migrate_999_500.ml.patch
            ./ppxlib_ast/ppxlib+astlib+parse.mli.patch
            ./ppxlib_ast/ppxlib+astlib+pprintast.ml.patch
            ./ppxlib_ast/ppxlib+astlib+pprintast.mli.patch
            ./ppxlib_ast/ppxlib+astlib+stdlib0.ml.patch
            ./ppxlib_ast/ppxlib+stdppx+stdppx.ml.patch
            ./ppxlib_ast/dune.patch
          ];
          propagatedBuildInputs = with ofinal;
            [
              stdlib-shims
              sexplib0
              ocaml-compiler-libs
            ];
        };
        ppxlib_jane = janePackage {
          name = "ppxlib_jane";
          rev = "f62221afd57959be2358ce66586843f75530ac9e";
          hash = "sha256-sud9/34jjzx+Y4K6ubAvuQ3WoS28LlN9GyuJqzD+qqU=";
          deps = with ofinal; [ ppxlib_ast ];
        };
        ppx_hash = janePackage {
          name = "ppx_hash";
          rev = "4469bf767328acc5b79c6d8ffe54b216989e3399";
          hash = "sha256-mr0tFJfraWMEt4hrV7GncDVcMK/Rjo15B6CiMwl5AAc=";
          deps = with ofinal;
            [
              ppxlib
              ppx_sexp_conv
              ppx_compare
            ];
        };
        ppx_enumerate = janePackage {
          name = "ppx_enumerate";
          rev = "58f6ee3427eca3ec9eae3671039b19680de34e53";
          hash = "sha256-/i606ARDCt+Vub20cw3+uB6vTAKNW6oDiUTl7lew5B0=";
          deps = with ofinal; [ ppxlib ppxlib_jane ];
        };
        ppx_cold = janePackage {
          name = "ppx_cold";
          rev = "6816f76e127fc4c586be5a5de04fd31953bf8b07";
          hash = "sha256-p2/Xf36VgLsnEzpXdTN9FfhXpq+mWIb/JfuGIFo1YG0=";
          deps = with ofinal; [ ppxlib ];
        };
        ppx_base = janePackage {
          name = "ppx_base";
          rev = "8eae4968739c377efb43526ce1631c32ab268ac6";
          hash = "sha256-UuRMjWoSlLvzo6NeGhE8Enp+/KCcnOwLw7c+YGyrWtQ=";
          deps = with ofinal;
            [
              ppxlib
              ppx_template
              ppx_shorthand
              ppx_hash
              ppx_globalize
              ppx_enumerate
              ppx_cold
            ];
        };
        ppx_globalize = janePackage {
          name = "ppx_globalize";
          rev = "1158e4a2527772774a0c686de7a0d8b89ac96099";
          hash = "sha256-nQbQeaVesBIkByv4VPYldZXEUFXjYKkRqGL4D9DYkQ4=";
          deps = with ofinal; [ ppxlib ];
        };
        ppx_shorthand = janePackage {
          name = "ppx_shorthand";
          rev = "6f19280c74746b9edd4133ebd080033e186d36d1";
          hash = "sha256-mE8IiPYZGRvSU/3xtoooftdftVoo4TKcmilOinxBWek=";
          deps = with ofinal; [ ppxlib ];
        };
        ppx_template = janePackage {
          name = "ppx_template";
          rev = "d12f4c8159a733ed9c4f565beb23ee5b518acf0c";
          hash = "sha256-bdZqefXyG19UunrWXV0JoGNp7AnZTWuyWv9PQEuS3nw=";
          deps = with ofinal; [ ppxlib ];
        };
        ocaml_intrinsics_kernel = janePackage {
          name = "ocaml_intrinsics_kernel";
          rev = "4393056d4730c66fd286404ff15b102705d028d2";
          hash = "sha256-e+zDYYoENJJ3jJB9aBJYqIaQH70X7XsfZiD4joVni7A=";
        };
        base = janePackage {
          name = "base";
          rev = "e81593a8a5f78b0f8b2087d83197625f33876b48";
          hash = "sha256-JBdK/zWiNv5+PEap6v4xGha+CqfdL7VzN8ucYni2Ovg=";
          deps = with ofinal;
            [
              dune-configurator
              ppx_base
              ocaml_intrinsics_kernel
            ];
        };
      });
}
