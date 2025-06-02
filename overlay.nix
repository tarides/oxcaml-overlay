# TODO:
# - why do we need to patch the compiler (cmxs etc)?
#   - using dune 3.9.3 does not change it.
# - import ocaml-variant files
# - ppxlib: import astlib dir
final: prev:
let
  preview26 = "v0.18~preview.130.26+1192";
  preview31 = "v0.18~preview.130.31+242";
  preview33 = "v0.18~preview.130.33+516";
  info = {
    "${preview26}" = import ./preview26.nix;
    "${preview31}" = import ./preview31.nix;
    "${preview33}" = import ./preview33.nix;
  };
  fetchFromGitHub = prev.fetchFromGitHub;
  buildDunePackage = final.ocamlPackages.buildDunePackage;
  janePackage = { name, deps ? [ ] }:
    let version = preview31; in
    buildDunePackage {
      inherit version;
      pname = name;
      src = fetchFromGitHub {
        inherit (info."${version}"."${name}") rev hash;
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
              tag = "5.2.0minus-10";
              hash = "sha256-14Idi4hAkObbA/Att06olgRmrDaMdsdPa0fC1JjYW8A=";
            };
          nativeBuildInputs = [
            final.autoconf
            final.rsync
            init.ocaml
            init.menhir
            init.dune
          ];
          version = "5.2.0minus-10";
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
          propagatedBuildInputs = with ofinal; [ merlin-lib yojson ];
        };
        merlin-lib = buildDunePackage {
          pname = "merlin-lib";
          inherit (ofinal.merlin) version src;
          propagatedBuildInputs = with ofinal; [ csexp ];
        };
        ocamlformat_0_26_2_jst = buildDunePackage {
          pname = "ocamlformat";
          version = "0.26.2+jst";
          src = fetchFromGitHub {
            owner = "janestreet";
            repo = "ocamlformat";
            rev = "317ea94a6d89ffac09c41be39233e83dcbaac603";
            hash = "sha256-KEHA1iw6ahMGOiTLR0Cwv7dmyXP31lsMwaU9EdIrzC0=";
          };
          propagatedBuildInputs = with ofinal;
            [
              csexp
              ocamlformat-lib_0_26_2_jst
              re
            ];
        };
        ocamlformat-lib_0_26_2_jst = buildDunePackage {
          pname = "ocamlformat-lib";
          inherit (ofinal.ocamlformat_0_26_2_jst) src version;
          nativeBuildInputs = with ofinal; [ menhir ];
          propagatedBuildInputs = with ofinal;
            [
              astring
              camlp-streams
              cmdliner
              dune-build-info
              either
              fpath
              menhirLib
              ocaml-version
              ocp-indent
              stdio
              uuseg
            ];
        };
        ppx_compare =
          janePackage {
            name = "ppx_compare";
            deps = with ofinal; [ ppxlib ];
          };
        sexplib0 = janePackage {
          name = "sexplib0";
          deps = with ofinal; [ basement ];
        };
        ppx_sexp_conv = janePackage {
          name = "ppx_sexp_conv";
          deps = with ofinal; [ ppxlib basement ];
        };
        basement = janePackage {
          name = "basement";
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
            ./ppxlib/ppxlib+src+utils.mli.patch
            ./ppxlib/ppxlib+traverse+ppxlib_traverse.ml.patch
            ./ppxlib/dune.patch
            ./ppxlib/location_check.ml.patch
            ./ppxlib/utils.ml.patch
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
          deps = with ofinal; [ ppxlib_ast ];
        };
        ppx_hash = janePackage {
          name = "ppx_hash";
          deps = with ofinal;
            [
              ppxlib
              ppx_sexp_conv
              ppx_compare
            ];
        };
        ppx_enumerate = janePackage {
          name = "ppx_enumerate";
          deps = with ofinal; [ ppxlib ppxlib_jane ];
        };
        ppx_cold = janePackage {
          name = "ppx_cold";
          deps = with ofinal; [ ppxlib ];
        };
        ppx_base = janePackage {
          name = "ppx_base";
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
          deps = with ofinal; [ ppxlib ];
        };
        ppx_shorthand = janePackage {
          name = "ppx_shorthand";
          deps = with ofinal; [ ppxlib ];
        };
        ppx_template = janePackage {
          name = "ppx_template";
          deps = with ofinal; [ ppxlib ];
        };
        ocaml_intrinsics_kernel = janePackage {
          name = "ocaml_intrinsics_kernel";
        };
        base = janePackage {
          name = "base";
          deps = with ofinal;
            [
              dune-configurator
              ppx_base
              ocaml_intrinsics_kernel
            ];
        };
        ppx_expect = janePackage {
          name = "ppx_expect";
          deps = with ofinal;
            [
              base
              ppx_here
              ppx_inline_test
              ppxlib
              stdio
            ];
        };
        ppx_optcomp = janePackage {
          name = "ppx_optcomp";
          deps = with ofinal; [ stdio ];
        };
        ppx_here = janePackage {
          name = "ppx_here";
          deps = with ofinal; [ base ppxlib ];
        };
        ppx_assert = janePackage {
          name = "ppx_assert";
          deps = with ofinal;
            [
              base
              ppx_here
              ppxlib
              ppx_sexp_conv
            ];
        };
        ppx_inline_test = janePackage {
          name = "ppx_inline_test";
          deps = with ofinal; [ ppxlib time_now ];
        };
      });
}
