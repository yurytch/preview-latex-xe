;;; px.el --- preview inline latex in any mode

;; Copyright (C) 2024 Yury Tarasievich <yurytch@github>
;; Copyright (C) 2014 Aurélien Aptel <aurelien.aptel@gmail.com>
;; Copyright (C) 2013 Rüdiger Sonderfeld <ruediger@c-plusplus.de>

;; Author: Aurélien Aptel <aurelien.aptel@gmail.com>
;; URL: http://github.com/aaptel/preview-latex
;; Version: 1.1


;;; Commentary:

;; Provides functions to preview LaTeX codes like $x^2$ in any
;; buffer/mode.

;; Use `px-preview-region' to preview LaTeX codes delimited by $ pairs
;; in the region.
;; Use `px-preview' to process the whole buffer.
;; Use `px-remove' to remove all images and restore the text back.
;; Use `px-toggle' to toggle between images and text on the whole
;; buffer.

;; Most of this code comes from weechat-latex.el which in turn uses
;; org-mode previewer.


;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'org)

(defvar px-temp-file-prefix "px-"
  "Prefix for temporary files.")

(defvar px-temp-directory-prefix "px-"
  "Prefix for temporary directory.")

(defvar px-image-program org-latex-create-formula-image-program
  "Program to convert LaTeX fragments.
See `org-latex-create-formula-image-program'")

(defvar px-temp-dir nil
  "The temporary directory used for preview images.")

(defvar px--active nil)
(make-variable-buffer-local 'px--active)

(defvar px--xelatex-png-mod-active nil)
  (make-variable-buffer-local 'px--xelatex-mod-png-active)

(defun px--xelatex-png-dpi ()
  "Calculate DPI for conversion from XeLaTeX-generated PDF to PNG.
   {(14/10)? * emacs_font_height_px / ((10/72.0) * 72)}  * xetex_pdf_dpi "
  (ceiling 
    (* 72.0  ; standard DPI in XeTeX PDF
      (/ (aref (font-info (face-font 'default)) 3) ; total emacs font height in px
         (* 72.0 (/ 10.0 72.0 )) ; pixels in 10 pt (default for XeTeX?) glyph height
      )
    )
  )
)

(defvar px--xelatex-png-image-converter
  (concat "pdftoppm -png -singlefile "
    "-r __DPI__ "
    "-W -1 -H -1 %o/%b.pdf %o/1 " 
    "&& convert %o/1.png -trim %O && rm %o/1.png " )  )

(defun px--adjust-xelatex-png-image-converter ()
  "Return xelatex-png image converter description string with DPI adjusted."
  (replace-regexp-in-string 
    "__DPI__" (number-to-string (px--xelatex-png-dpi)) px--xelatex-png-image-converter)
)

(defun px--xelatex-png-init ()
  "Init and insert modifications of ORG structures."
  (unless px--xelatex-png-mod-active
    (setq org-preview-latex-process-alist--xelatex-png
      (list
        'xelatex-png 
        ':programs '("xelatex" "pdftoppm" "convert")
        ':description "pdf > png"
        ':message "you need to install packages for: xetex, poppler and imagemagick."
        ':image-input-type "pdf"
        ':image-output-type "png"
        ':image-size-adjust '(1.0 . 1.0)
        ':latex-compiler '("xelatex -interaction nonstopmode -output-directory %o %f") 
        ':image-converter (list px--xelatex-png-image-converter)
      )
    )
    (setq org-preview-latex-process-alist
      (cons
        org-preview-latex-process-alist--xelatex-png
        org-preview-latex-process-alist
      )
    )
    (setq org-latex-create-formula-image-program 'xelatex-png)
    ; alias, obsolete in org 9.*
    (setq org-preview-latex-default-process 'xelatex-png)
    ; separate defvar in px
    (setq px-image-program 'xelatex-png)
    (setq px--xelatex-png-mod-active t)
  ) ; end of unless
)

(defun px--create-preview (&optional beg end)
  "Wrapper for `org-format-latex'.
The parameter AT should be nil or in (TYPE . POINT) format.  With TYPE being a
string showing the matched LaTeX statement (e.g., ``$'') and POINT being the
POINT to replace.  If AT is nil replace statements everywhere."
  (setcdr (assq 'xelatex-png org-preview-latex-process-alist)
    (plist-put (alist-get 'xelatex-png org-preview-latex-process-alist)
      :image-converter
      (list (px--adjust-xelatex-png-image-converter))
    )
  )
  (if (version< "9" org-version)
      (org-format-latex px-temp-file-prefix
                        beg end
                        temporary-file-directory
                        'overlays
                        "Creating images...%s"
                        'forbuffer
                        px-image-program)
    (condition-case e
        (org-format-latex px-temp-file-prefix
                          px-temp-dir
                          'overlays
                          "Creating images...%s"
                          (if beg (cons "$" beg) nil)
                          'forbuffer
                          px-image-program)

      ;; if wrong arity, try with one less argument (cf. issue #1)
      (wrong-number-of-arguments
       (org-format-latex px-temp-file-prefix
                         px-temp-dir
                         'overlays
                         "Creating images...%s"
                         'forbuffer
                         px-image-program)))))


(defun px--set-temp-dir ()
  "Set `px-temp-dir' unless it is already set."
  (unless px-temp-dir
    (setq px-temp-dir
          (make-temp-file px-temp-directory-prefix
                          'directory))))

;;;###autoload
(defun px-preview ()
  "Preview LaTeX fragments in the current buffer."
  (interactive)
  (save-excursion
    (let ((inhibit-read-only t))
      (px--xelatex-png-init)
      (px--set-temp-dir)
      (px-remove)
      (px--create-preview)
      (setq px--active t))))

;;;###autoload
(defun px-preview-region (beg end)
  "Preview LaTeX fragments in region."
  (interactive "r")
  (let* ((math-regex (assoc "$" org-latex-regexps))
         (regex (nth 1 math-regex))
         (n (nth 2 math-regex))
         matches)
    (save-excursion
      (goto-char beg)
      (while (re-search-forward regex end t)
        (setq matches (cons (cons (match-beginning n) (match-end n)) matches)))
      (let ((inhibit-read-only t))
        (px--set-temp-dir)
        (dolist (i matches)
          (px--create-preview i))))))

;;;###autoload
(defun px-remove ()
  "Remove LaTeX preview images in current buffer."
  (interactive)
  (let ((inhibit-read-only t))
    (if (version< "9" org-version)
        (delete-all-overlays)
      (org-remove-latex-fragment-image-overlays)))
  (setq px--active nil))

;;;###autoload
(defun px-toggle ()
  "Toggle display of LaTeX preview in the current buffer."
  (interactive)
  (if px--active
      (px-remove)
    (px-preview)))


(provide 'px)

;;; px.el ends here
