(defun org-keys ()
  (interactive)
  ;; Make ~SPC ,~ work, reference:
  ;; http://stackoverflow.com/questions/24169333/how-can-i-emphasize-or-verbatim-quote-a-comma-in-org-mode
  (setcar (nthcdr 2 org-emphasis-regexp-components) " \t\n")
  (org-set-emph-re 'org-emphasis-regexp-components org-emphasis-regexp-components)

  (setq org-emphasis-alist '(("*" bold)
                             ("/" italic)
                             ("_" underline)
                             ("=" org-verbatim verbatim)
                             ("~" org-kbd)
                             ("+"
                              (:strike-through t))))

  (setq org-hide-emphasis-markers t))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "M-h") 'org-metaleft)
  (define-key org-mode-map (kbd "M-j") 'org-metadown)
  (define-key org-mode-map (kbd "M-k") 'org-metaup)
  (define-key org-mode-map (kbd "M-l") 'org-metaright)
  (define-key org-mode-map (kbd "M-H") 'org-shiftmetaleft)
  (define-key org-mode-map (kbd "M-J") 'org-shiftmetadown)
  (define-key org-mode-map (kbd "M-K") 'org-shiftmetaup)
  (define-key org-mode-map (kbd "M-L") 'org-shiftmetaright)
  (org-keys)

  (add-to-list 'org-log-note-headings '(note . "%t")))

(spacemacs/set-leader-keys "bo" 'org-iswitchb)
(spacemacs/set-leader-keys "oh" 'counsel-org-agenda-headlines)

(setq org-mobile-force-id-on-agenda-items nil)
(setq org-startup-indented t)
(setq org-agenda-todo-ignore-scheduled t)
(setq org-agenda-todo-ignore-deadlines t)
(setq org-blank-before-new-entry '((heading . nil) (plain-list-item . nil)))
(setq org-agenda-sticky t)

(setq org-todo-keywords
      (quote ((sequence "TODO(t)" "|" "DONE(d)")
              (sequence "WAITING(w@/!)" "|" "CANCELLED(c@/!)"))))


(setq org-todo-keyword-faces
      (quote (("TODO" :foreground "#F92672" :weight bold)
              ("DONE" :foreground "#A6E22E" :weight bold)
              ("WAITING" :foreground "#FD971F" :weight bold)
              ("CANCELLED" :foreground "#A6E22E" :weight bold))))

(setq org-todo-state-tags-triggers
      (quote (("CANCELLED" ("CANCELLED" . t))
              ("WAITING" ("WAITING" . t))
              (done ("WAITING") ("HOLD"))
              ("TODO" ("WAITING") ("CANCELLED") ("HOLD"))
              ("DONE" ("WAITING") ("CANCELLED") ("HOLD")))))

(setq org-use-fast-todo-selection t)

(add-hook 'org-capture-mode-hook 'evil-insert-state)
(add-hook 'org-log-buffer-setup-hook 'evil-insert-state)

;; Refresh calendars via org-gcal and automatically create appt-reminders.
;; Appt will be refreshed any time an org file is saved after 10 seconds of idle.
;; gcal will be synced after 1 minute of idle every 15 minutes.
;; Start with `(aj-sync-calendar-start)'
(defvar aj-refresh-appt-timer nil
  "Timer that `aj-refresh-appt-with-delay' uses to reschedule itself, or nil.")
(defun aj-refresh-appt-with-delay ()
  (when aj-refresh-appt-timer
    (cancel-timer aj-refresh-appt-timer))
  (setq aj-refresh-appt-timer
        (run-with-idle-timer
         10 nil
         (lambda ()
           (setq appt-time-msg-list nil)
           (let ((inhibit-message t))
             (org-agenda-to-appt))))))

(defvar aj-sync-calendar-timer nil
  "Timer that `aj-sync-calendar-with-delay' uses to reschedule itself, or nil.")
(defun aj-sync-calendar-with-delay ()
  (when aj-sync-calendar-timer
    (cancel-timer aj-sync-calendar-timer))
  (setq aj-sync-calendar-timer
        (run-with-idle-timer
         60 nil
         (lambda ()
           (let ((inhibit-message t))
             (org-gcal-refresh-token)
             (org-gcal-fetch))))))

(defun aj-sync-calendar-start ()
  (add-hook 'after-save-hook
            (lambda ()
              (when (eq major-mode 'org-mode)
                (aj-refresh-appt-with-delay))))

  (run-with-timer
   0 (* 15 60)
   'aj-sync-calendar-with-delay))

(defun aj/org-save-all-org-buffers (&rest _)
  (org-save-all-org-buffers))
(advice-add 'org-agenda-quit :before 'aj/org-save-all-org-buffers)
(advice-add 'org-agenda-todo :after 'aj/org-save-all-org-buffers)
(advice-add 'org-agenda-deadline :after 'aj/org-save-all-org-buffers)
(advice-add 'org-agenda-schedule :after 'aj/org-save-all-org-buffers)

;; Custom org-agenda view
(setq org-agenda-compact-blocks t)
(setq org-agenda-custom-commands
      (quote ((" " "Agenda"
               ((agenda "" ((org-agenda-span 'day)))
                (tags "REFILE"
                      ((org-agenda-overriding-header "Tasks to Refile")
                       (org-tags-match-list-sublevels nil)))
                (tags-todo "-REFILE/!"
                           ((org-agenda-overriding-header "Tasks")
                            (org-agenda-skip-function '(org-agenda-skip-entry-if 'deadline 'scheduled))))
                (tags "-REFILE/"
                      ((org-agenda-overriding-header "Tasks to Archive")
                       (org-agenda-skip-function 'aj/skip-non-archivable-tasks)
                       (org-tags-match-list-sublevels nil))))))))

(defun aj/skip-non-archivable-tasks ()
  "Skip trees that are not available for archiving"
  (save-restriction
    (widen)
    ;; Consider only tasks with done todo headings as archivable candidates
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max))))
          (subtree-end (save-excursion (org-end-of-subtree t))))
      (if (member (org-get-todo-state) org-todo-keywords-1)
          (if (member (org-get-todo-state) org-done-keywords)
              (let* ((daynr (string-to-int (format-time-string "%d" (current-time))))
                     (a-month-ago (* 60 60 24 (+ daynr 1)))
                     (last-month (format-time-string "%Y-%m-" (time-subtract (current-time) (seconds-to-time a-month-ago))))
                     (this-month (format-time-string "%Y-%m-" (current-time)))
                     (subtree-is-current (save-excursion
                                           (forward-line 1)
                                           (and (< (point) subtree-end)
                                                (re-search-forward (concat last-month "\\|" this-month) subtree-end t)))))
                (if subtree-is-current
                    subtree-end ; Has a date in this month or last month, skip it
                  nil))  ; available to archive
            (or subtree-end (point-max)))
        next-headline))))
(defun org-agenda-show-agenda (&optional arg)
  (interactive "P")
  (org-agenda arg " ")
  (org-agenda-redo))
(spacemacs/set-leader-keys "oa" 'org-agenda-show-agenda)

;; org-refile settings
(setq org-refile-targets '((nil :maxlevel . 9)
                           (org-agenda-files :maxlevel . 9)))
(setq org-refile-use-outline-path t)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-allow-creating-parent-nodes 'confirm)

(defun aj/verify-refile-target ()
  "Exclude todo keywords with a done state and org-gcal files"
  (and (not (member (nth 2 (org-heading-components)) org-done-keywords))
       (not (member buffer-file-name (mapcar #'cdr org-gcal-file-alist)))))

(setq org-refile-target-verify-function 'aj/verify-refile-target)

;; org-capture settings
(setq org-capture-templates
      '(("n" "Notes" entry
         (file (concat org-directory "/refile.org"))
         "* %? :NOTE:\n%U\n%a")
        ("t" "Todo" entry
         (file+headline (concat org-directory "/todo.org") "To Do")
         "* TODO %?\n%U\n%a")
        ("s" "Scheduled Task" entry
         (file+headline (concat org-directory "/schedule.org") "Tasks")
         "* TODO %?\nSCHEDULED: %^{When}t")))

(setq org-projectile:capture-template "* TODO %?\n%U\n%a")

;; gnuplot settings
(advice-add 'org-plot/gnuplot :after #'org-redisplay-inline-images)

;; https://lists.gnu.org/archive/html/emacs-orgmode/2017-04/msg00062.html
(with-eval-after-load 'org-mobile
  (defun org-mobile-get-outline-path-link (pom)
    (org-with-point-at pom
      (concat "olp:"
              (org-mobile-escape-olp (file-name-nondirectory buffer-file-name))
              ":"
              (mapconcat 'org-mobile-escape-olp
                         (org-get-outline-path)
                         "/")
              "/"
              (org-mobile-escape-olp (nth 4 (org-heading-components)))))))

(provide 'init-org)
