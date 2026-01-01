;;; esbonio.el --- Esbonio language server integration -*- lexical-binding: t -*-

;; Copyright (C) 2024-2025 Alex Carney

;; Author: Alex Carney <alcarneyme@gmail.com>
;; URL: https://github.com/swyddfa/esbonio.el
;; Version: 0.2.1
;; Package-Requires: ((emacs "30.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; This file is NOT part of GNU Emacs.

;;; Commentary:



;;; Code:


(defgroup esbonio nil
  "Esbonio language server."
  :prefix "esbonio-"
  :group 'applications)

(defcustom esbonio-server-command (list (executable-find "esbonio"))
  "Command to use when launching the esbonio server"
  :type '(repeat (string))
  :group 'esbonio)

(defvar esbonio-managed-buffer-predicate nil
  "Predicate function for determining if the given buffer is managed by esbonio")

(defvar esbonio-preview-file-function nil
  "Function to call when generating the preview of a given file.")

(defvar esbonio-scroll-view-function nil
  "Function to call when scrolling the documentation preview")

(defun esbonio-preview-file ()
  "Preview the current file visited by the current buffer."
  (interactive)
  (if (and buffer-file-name
           esbonio-preview-file-function)
      (funcall esbonio-preview-file-function buffer-file-name)
    (message "Unable to preview file %s %s"
             (if buffer-file-name "" "[buffer is not visiting a file]")
             (if esbonio-preview-file-function "" "[esbonio-preview-file-function is not set]"))))

(define-minor-mode esbonio-sync-scroll-mode
  "When enabled, synchronise the window's scroll state with the
documentation preview."
  :global t
  :lighter nil
  (if esbonio-sync-scroll-mode
      ;; TODO: `window-scroll-functions' are not called when scrolling
      ;; via `pixel-scroll-precision-mode'.  As far as I can tell this
      ;; was reported by not fixed?
      ;; https://mail.gnu.org/archive/html/bug-gnu-emacs/2023-02/msg00357.html
      (add-hook 'window-scroll-functions 'esbonio--window-scrolled)
    (remove-hook 'window-scroll-functions 'esbonio--window-scrolled)))

(defun esbonio--window-scrolled (win pos)
  "Hook called when a window's scroll state changes"
  (if-let ((buffer (window-buffer win))
           (_ (esbonio-managed-buffer-p buffer))
           (line (line-number-at-pos pos)))
      (progn ;; (message "%s @ line %s" buffer line)
        (if esbonio-scroll-view-function
            (funcall esbonio-scroll-view-function buffer line)))))

(defun esbonio-managed-buffer-p (buffer)
  "Returns t if BUFFER is managed by esbonio."
  (if esbonio-managed-buffer-predicate
      (funcall esbonio-managed-buffer-predicate buffer)))



;; Eglot integration

;;;###autoload
(defun esbonio-eglot-ensure ()
  "Load esbonio.el's integrations with eglot, then call `eglot-ensure'"
  ;; This function is mainly here to ensure that the below
  ;; customisations are loaded *before* starting eglot
  (require 'eglot)
  (eglot-ensure))

(with-eval-after-load 'eglot

  (eval-and-compile  ; Trying to keep the byte-compiler happy...
    (require 'eglot))

  (defclass eglot-esbonio (eglot-lsp-server) ()
    :documentation "Esbonio language server.")

  (add-to-list 'eglot-server-programs
               `(rst-mode . ,(append '(eglot-esbonio) esbonio-server-command)))

  (defun esbonio--eglot-preview-file (file-name)
    "`esbonio-preview-file-function' implementation for eglot."
    (let ((server (eglot-current-server))
          (uri (eglot-path-to-uri file-name)))
      (if server
          (eglot-execute server `(:command "esbonio.server.previewFile"
                                           :arguments ,(vector `(:uri ,uri)))))))
  (setq esbonio-preview-file-function 'esbonio--eglot-preview-file)

  (defun esbonio--eglot-managed-buffer-p (buffer)
    "`esbonio-managed-buffer-predicate' implementation for eglot"
    (defvar eglot-esbonio) ; Somehow needed to keep the byte-compiler happy...
    (with-current-buffer buffer
      (and (eglot-managed-p)
           (same-class-p (eglot-current-server) eglot-esbonio))))
  (setq esbonio-managed-buffer-predicate 'esbonio--eglot-managed-buffer-p)

  (defun esbonio--eglot-scroll-view (buffer line)
    "`esbonio-scroll-view-function' implementation for eglot"
    (if-let ((server (eglot-current-server))
             (file-name (with-current-buffer buffer buffer-file-name))
             (uri (eglot-path-to-uri file-name)))
        (progn ;; (message "scroll %s @ %s" uri line)
          (jsonrpc-notify server :view/scroll `(:uri ,uri :line ,line)))))
  (setq esbonio-scroll-view-function 'esbonio--eglot-scroll-view)

  (declare-function eglot-esbonio--eieio-childp nil) ; For the byte compiler
  )



;; lsp-mode integration

;;;###autoload
(defun esbonio-lsp ()
  "Load esbonio.el's integrations with lsp-mode, then call `lsp'"
  ;; This function is mainly here to ensure that the below
  ;; customisations are loaded *before* starting eglot
  (require 'lsp-mode)
  (lsp))

;;;###autoload
(defun esbonio-lsp-deferred ()
  "Load esbonio.el's integrations with lsp-mode, then call `lsp-deferred'"
  ;; This function is mainly here to ensure that the below
  ;; customisations are loaded *before* starting eglot
  (require 'lsp-mode)
  (lsp-deferred))


(with-eval-after-load 'lsp-mode

  (eval-and-compile  ; Trying to keep the byte-compiler happy...
    (require 'lsp-mode nil t))

  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection (lambda () esbonio-server-command))
    :activation-fn (lsp-activate-on "restructuredtext")
    :server-id 'esbonio))

  (defun esbonio--lsp-mode-managed-buffer-p (buffer)
    "`esbonio-managed-buffer-predicate' implementation for lsp-mode."
    (with-current-buffer buffer
      ;; This seems harder than it should be....
      (if-let* ((root (project-root (project-current)))
                (folder->servers (lsp-session-folder->servers (lsp-session)))
                (workspaces (or (gethash root folder->servers nil)
                                ;; `project-root' includes the final "/" while `folder->servers' does not
                                (gethash (substring root 0 -1) folder->servers nil)))
                ;; Assume a single server process for now...
                (workspace (car workspaces))
                (client (lsp--workspace-client workspace))
                (server-id (lsp--client-server-id client)))
          (eq server-id 'esbonio))))
  (setq esbonio-managed-buffer-predicate 'esbonio--lsp-mode-managed-buffer-p)

  (defun esbonio--lsp-mode-preview-file (file-name)
    "`esbonio-preview-file-function' implementation for lsp-mode."
    (let* ((uri (lsp--path-to-uri file-name))
           (result (lsp-workspace-command-execute "esbonio.server.previewFile"
                                                  (vector `(:uri ,uri)))))
      ;; While lsp-mode implements 'window/showDocument', it doesn't support
      ;; external uris (e.g. http://...). So it is up to us to open the
      ;; uri returned from the server
      (if (gethash "uri" result nil)
          (browse-url (gethash "uri" result)))))
  (setq esbonio-preview-file-function 'esbonio--lsp-mode-preview-file)

  (defun esbonio--lsp-mode-scroll-view (buffer line)
    "`esbonio-scroll-view-function' implementation for lsp-mode"
    (if-let ((file-name (with-current-buffer buffer buffer-file-name))
             (uri (lsp--path-to-uri file-name)))
        (progn ;; (message "scroll %s @ %s" uri line)
          (lsp-notify "view/scroll" `(:uri ,uri :line ,line)))))
  (setq esbonio-scroll-view-function 'esbonio--lsp-mode-scroll-view))


(provide 'esbonio)
;;; esbonio.el ends here
