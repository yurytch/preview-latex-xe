
px.el is an Emacs Lisp library that provides functions to preview
LaTeX codes like $x^2$ in any buffer/mode.

Most of this code comes from weechat-latex.el which in turn uses
org-mode previewer.

Installation
============

Place px.el somewhere on your load-path and load it.

Usage
=====

- Use `px-preview-region` to preview LaTeX codes delimited by $ pairs
  in the region.
- Use `px-preview` to process the whole buffer.
- Use `px-remove` to remove all images and restore the text back.
- Use `px-toggle` to toggle between images and text on the whole
  buffer.

Changes
=======
2024-02-17: Initial upload by @yurytch
As compared with the original project https://github.com/aaptel/preview-latex , there are two enhancements:
1. The DPI parameter for previews is now auto-adjusted with regard to Emacs font screen size.
2. Code was added to make possible using XeLaTeX from TeX Live distro (there's no DVI stage there, so old logic wouldn't work anymore). Ideally, that kind of code should reside in Orgmode component, but I have it here at the moment.
