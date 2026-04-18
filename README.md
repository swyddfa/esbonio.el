# esbonio.el

Emacs package for integrating the [esbonio](https://github.com/swyddfa/esbonio) language server into Emacs, providing the necessary glue code for both `eglot` and `lsp-mode`

It also exposes the functionality provided by the language server that falls outside the LSP specification including live previews and syncronised scrolling

Requires Emacs 30.1

## Setup

Install the esbonio language using a tool like `uv`
```
uv tool install esbonio
```

or `pipx`

```
pipx install esbonio
```

Once installed, ensure the `esbonio` command is available on your `PATH`
```
$ esbonio --help
usage: esbonio [-h] [--version] {server} ...

The Esbonio language server

options:
  -h, --help  show this help message and exit
  --version   print the current version and exit.

commands:
  {server}
    server    launch the esbonio language server
```

### eglot

Add the following configuration to your ``init.el``

```elisp
(use-package esbonio
  :vc (esbonio :url "https://github.com/swyddfa/esbonio.el" :rev "main")
  :hook ((rst-mode . esbonio-eglot-ensure)))
```

### lsp-mode

Add the following configuration to your `init.el`

```elisp
(use-package esbonio
  :vc (esbonio :url "https://github.com/swyddfa/esbonio.el" :rev "main")
  :hook ((rst-mode . esbonio-lsp-deferred)))  ;; or `esbonio-lsp'
```

## Usage

See the upstream project's [documentation](https://docs.esbon.io/en/latest/) on using esbonio itself.

In addition to registering esbonio with the various lsp client packages, this package provides the following

- `esbonio-preview-file`: Function to open a preview for the current file
- `esbonio-sync-scroll-mode`: Global minor mode that synhronises the scroll state between Emacs and the documentation preview.
