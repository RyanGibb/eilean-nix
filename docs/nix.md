
# Nix

Nix is a software deployment system that uses cryptographic hashes to compute unique paths for components (i.e., packages) that are stored in a read-only directory: the Nix store, at `/nix/store/<hash>-<name>`.
This provides several benefits, including concurrent installation of multiple versions of a package, atomic upgrades, and multiple user environments.

Nix uses a declarative domain-specific language (DSL), also called Nix, to build and configure software.
The Nix DSL is a functional language with a syntax Turing complete but lacks a type system.
We use the DSL to write derivations for software, which describe how to build said software with input components and a build script.
This Nix expression is then 'instantiated' to create 'store derivations' (`.drv` files), which is the low-level representation of how to build a single component.
This store derivation is 'realised' into a built artefact, hereafter referred to as 'building'.

Possibly the simplest Nix derivation uses `bash` to create a single file containing `Hello, World!`:
```nix
{ pkgs ? import <nixpkgs> {  } }:

builtins.derivation {
  name = "hello";
  system = builtins.currentSystem;
  builder = "${nixpkgs.bash}/bin/bash";
  args = [ "-c" ''echo "Hello, World!" > $out'' ];
}
```
Note that `derivation` is a function that we're calling with one argument, which is a set of attributes.

We can instantiate this Nix derivation to create a store derivation:
```
$ nix-instantiate default.nix
/nix/store/5d4il3h1q4cw08l6fnk4j04a19dsv71k-hello.drv
$ nix show-derivation /nix/store/5d4il3h1q4cw08l6fnk4j04a19dsv71k-hello.drv
{
  "/nix/store/5d4il3h1q4cw08l6fnk4j04a19dsv71k-hello.drv": {
    "outputs": {
      "out": {
        "path": "/nix/store/4v1dx6qaamakjy5jzii6lcmfiks57mhl-hello"
      }
    },
    "inputSrcs": [],
    "inputDrvs": {
      "/nix/store/mnyhjzyk43raa3f44pn77aif738prd2m-bash-5.1-p16.drv": [
        "out"
      ]
    },
    "system": "x86_64-linux",
    "builder": "/nix/store/2r9n7fz1rxq088j6mi5s7izxdria6d5f-bash-5.1-p16/bin/bash",
    "args": [ "-c", "echo \"Hello, World!\" > $out" ],
    "env": {
      "builder": "/nix/store/2r9n7fz1rxq088j6mi5s7izxdria6d5f-bash-5.1-p16/bin/bash",
      "name": "hello",
      "out": "/nix/store/4v1dx6qaamakjy5jzii6lcmfiks57mhl-hello",
      "system": "x86_64-linux"
    }
  }
}
```

And build the store derivation:
```sh
$ nix-store --realise /nix/store/5d4il3h1q4cw08l6fnk4j04a19dsv71k-hello.drv
/nix/store/4v1dx6qaamakjy5jzii6lcmfiks57mhl-hello
$ cat /nix/store/4v1dx6qaamakjy5jzii6lcmfiks57mhl-hello
Hello, World!
```

Most Nix tooling does these two steps together:
```
nix-build default.nix
this derivation will be built:
  /nix/store/q5hg3vqby8a9c8pchhjal3la9n7g1m0z-hello.drv
building '/nix/store/q5hg3vqby8a9c8pchhjal3la9n7g1m0z-hello.drv'...
/nix/store/zyrki2hd49am36jwcyjh3xvxvn5j5wml-hello
```

Nix realisations (hereafter referred to as 'builds') are done in isolation to ensure reproducibility.
Projects often rely on interacting with package managers to make sure all dependencies are available and may implicitly rely on system configuration at build time.
To prevent this, every Nix derivation is built in isolation (without network access or access to the global file system) with only other Nix derivations as inputs.

> The name Nix is derived from the Dutch word *niks*, meaning nothing; build actions do not see anything that has not been explicitly declared as an input.

For more information, see:
- The Nix paper: https://edolstra.github.io/pubs/nspfssd-lisa2004-final.pdf
- The Nix PhD thesis: https://edolstra.github.io/pubs/phd-thesis.pdf

