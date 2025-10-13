(defgroup crio/devloop nil
  "CriomOS development loop helpers."
  :group 'tools
  :prefix "crio/")

(defcustom crio/aider-default-command
  "aider --model openai/gpt-4o-mini --no-auto-commit"
  "Shell command used by `crio/aider-vterm' to start aider."
  :type 'string
  :group 'crio/devloop)

(defcustom crio/gptel-system-prompt
  "You are an expert NixOS, Emacs and systems programming pair-programmer."
  "System prompt supplied to gptel helper commands."
  :type 'string
  :group 'crio/devloop)

(defcustom crio/gptel-default-model "gpt-4o-mini"
  "Default model identifier used for gptel sessions."
  :type 'string
  :group 'crio/devloop)

(defun crio/gptel--read-api-key ()
  "Lookup an OpenAI compatible API key for gptel.
The function first checks `OPENAI_API_KEY' and then pass entry
`openai/api-key' for backwards compatibility."
  (or (getenv "OPENAI_API_KEY")
      (ignore-errors
        (when (fboundp 'auth-source-pass-get)
          (or (auth-source-pass-get "token" "openai/api-key")
              (auth-source-pass-get "password" "openai/api-key"))))))

(use-package copilot
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . copilot-accept-completion)
              ("TAB" . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("M-<tab>" . copilot-accept-completion-by-line))
  :init
  (setq copilot-disable-predicates '(copilot--buffer-changed-p))
  :config
  (setq copilot-node-executable (or (executable-find "node")
                                    copilot-node-executable))
  (define-key global-map (kbd "C-c ]") #'copilot-accept-completion)
  (with-eval-after-load 'company
    (define-key company-active-map (kbd "<tab>") nil)
    (define-key company-active-map (kbd "TAB") nil))
  (with-eval-after-load 'projectile
    (define-key projectile-command-map (kbd "]") #'copilot-mode)))

(use-package gptel
  :commands (gptel gptel-send gptel-rewrite gptel-menu)
  :custom
  (gptel-default-mode 'org-mode)
  (gptel-use-curl t)
  :init
  (setq gptel-model crio/gptel-default-model)
  :config
  (let ((backend
         (gptel-make-openai "openai"
           :key #'crio/gptel--read-api-key
           :models (list crio/gptel-default-model "gpt-4o" "gpt-4o-mini"))))
    (setq gptel-backend backend)
    (setq gptel-default-backend backend))
  (defun crio/gptel--ensure-buffer (name)
    (let ((buffer (get-buffer-create name)))
      (with-current-buffer buffer
        (unless (derived-mode-p 'gptel-mode)
          (gptel-mode))
        (setq-local gptel-system-prompt crio/gptel-system-prompt)
        (setq-local gptel-model crio/gptel-default-model))
      buffer))
  (defun crio/gptel-explain-region (beg end)
    "Explain the region between BEG and END in a dedicated gptel buffer."
    (interactive "r")
    (let* ((code (buffer-substring-no-properties beg end))
           (mode major-mode)
           (buffer (crio/gptel--ensure-buffer "*gptel-explain*"))
           (prompt (format "Explain the following %s code. Include intent, key APIs and follow-up ideas.\n\n```%s\n%s\n```"
                           mode mode code)))
      (gptel-request prompt
        :buffer buffer
        :system crio/gptel-system-prompt
        :model crio/gptel-default-model)))
  (defun crio/gptel-review-buffer ()
    "Summarise the current buffer using gptel."
    (interactive)
    (crio/gptel-explain-region (point-min) (point-max)))
  (defun crio/gptel-refactor-region (beg end instruction)
    "Ask gptel to rewrite region BEG..END according to INSTRUCTION."
    (interactive "r\nsRewrite instructions: ")
    (gptel-rewrite beg end instruction))
  (define-key global-map (kbd "C-c g g") #'gptel)
  (define-key global-map (kbd "C-c g e") #'crio/gptel-explain-region)
  (define-key global-map (kbd "C-c g b") #'crio/gptel-review-buffer)
  (define-key global-map (kbd "C-c g r") #'crio/gptel-refactor-region))

(use-package vterm
  :commands (vterm)
  :config
  (setq vterm-max-scrollback 10000)
  (defun crio/aider--project-root ()
    (cond
     ((and (boundp 'projectile-mode) projectile-mode (fboundp 'projectile-project-p)
           (projectile-project-p))
      (projectile-project-root))
     ((fboundp 'project-current)
      (when-let ((project (project-current)))
        (project-root project)))
     (t default-directory)))
  (defun crio/aider-vterm (&optional command)
    "Open a vterm running aider in the project root.
With prefix argument prompt for COMMAND, otherwise use
`crio/aider-default-command'."
    (interactive
     (list (when current-prefix-arg
             (read-shell-command "Aider command: " crio/aider-default-command))))
    (let* ((root (or (crio/aider--project-root) default-directory))
           (default-directory root)
           (buffer-name (format "*aider:%s*"
                                (file-name-nondirectory (directory-file-name root))))
           (cmd (or command crio/aider-default-command)))
      (vterm buffer-name)
      (vterm-send-string cmd)
      (vterm-send-return)))
  (define-key global-map (kbd "C-c a a") #'crio/aider-vterm)
  (with-eval-after-load 'projectile
    (define-key projectile-command-map (kbd "a") #'crio/aider-vterm)))

(provide 'crio-synth)
