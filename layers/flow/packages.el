(defconst flow-packages
  '(
    (flycheck-flow :toggle (configuration-layer/package-usedp 'flycheck))
    (company-flow :toggle (configuration-layer/package-usedp 'company))
    ))

(defun flow/init-flycheck-flow ()
  (use-package flycheck-flow
    :config
    (progn
      (flycheck-add-mode 'javascript-flow 'react-mode)
      (flycheck-add-mode 'javascript-flow 'rjsx-mode)
      (flycheck-add-next-checker 'javascript-flow 'javascript-eslint))))

(defun flow/init-company-flow ()
  (use-package company-flow
    :defer t
    :commands company-flow
    :init
    (progn
      (push 'company-flow company-backends-js2-mode)
      (push 'company-flow company-backends-react-mode))
    :config
    (add-to-list 'company-flow-modes 'react-mode)
    (add-to-list 'company-flow-modes 'rjsx-mode)))
