(in-package #:org.shirakumo.fraf.kandria)

(defclass menu-layout (alloy:border-layout alloy:renderable)
  ())

(presentations:define-realization (ui menu-layout)
  ((:bg simple:rectangle)
   (alloy:margins)
   :pattern (colored:color 0.15 0.15 0.15 0.5)))

(defmethod alloy:handle ((ev alloy:pointer-event) (focus menu-layout))
  (restart-case
      (call-next-method)
    (alloy:decline ()
      T)))

(defclass overview-focus-list (alloy:horizontal-focus-list)
  ())

(defmethod alloy:focus-prev ((list overview-focus-list))
  (if (= 0 (alloy:index list))
      (alloy:exit list)
      (call-next-method)))

(defclass vertical-menu-focus-list (alloy:vertical-focus-list)
  ())

(defmethod alloy:handle ((event alloy:focus-left) (bar vertical-menu-focus-list))
  (when (typep (alloy:focus-parent bar) 'tab)
    (alloy:exit bar)))

(defmethod alloy:handle ((event alloy:focus-right) (bar vertical-menu-focus-list))
  (alloy:activate bar))

(defclass vertical-tab-bar (alloy:vertical-linear-layout vertical-menu-focus-list alloy:observable alloy:renderable)
  ((alloy:min-size :initform (alloy:size 250 50))
   (alloy:cell-margins :initform (alloy:margins))))

(defmethod (setf alloy:focus) :before ((focus (eql :strong)) (bar vertical-tab-bar))
  (when (and (alloy:focused bar) (eql :strong (alloy:focus (alloy:focused bar))))
    (harmony:play (// 'sound 'ui-focus-out) :reset T)))

(defmethod (setf alloy:focus) :after ((focus (eql :strong)) (bar vertical-tab-bar))
  (cond ((null (alloy:index bar))
         (setf (alloy:index bar) 0))
        ((alloy:focused bar)
         (setf (alloy:focus (alloy:focused bar)) :weak))
        (T
         (setf (alloy:focused bar) (alloy:index-element (alloy:index bar) bar)))))

(defmethod alloy:notice-focus :after (focus (bar vertical-tab-bar))
  (alloy:mark-for-render bar))

(presentations:define-realization (ui vertical-tab-bar)
  ((:bg simple:rectangle)
   (alloy:margins)
   :pattern colors:black)
  ((:bord simple:rectangle)
   (alloy:extent (alloy:pw 1) (alloy:ph 0.01) -1 (alloy:ph 0.98))
   :pattern colors:white))

(defclass tab-view (alloy:structure)
  ((layout :accessor layout)))

(defmethod initialize-instance :after ((view tab-view) &key layout-parent focus-parent tabs)
  (let* ((layout (setf (layout view) (make-instance 'alloy:border-layout :layout-parent layout-parent)))
         (list (make-instance 'vertical-tab-bar :focus-parent focus-parent)))
    (alloy:enter list layout :place :west :size (alloy:un 250))
    (dolist (tab tabs)
      (apply #'add-tab view tab))
    (alloy:finish-structure view layout list)))

(defun add-tab (view name layout-element focus-element)
  (let ((tab (make-instance 'tab :value name)))
    (alloy:enter focus-element tab)
    (alloy:enter layout-element tab)
    (alloy:enter tab view)
    tab))

(defmethod alloy:enter ((element alloy:focus-element) (view tab-view) &key)
  (alloy:enter element (alloy:focus-element view)))

(defclass tab-button (alloy:label*)
  ())

(defmethod alloy:active-p ((button tab-button))
  (not (null (alloy:focus button))))

(presentations:define-realization (ui tab-button)
  ((:border simple:rectangle)
   (alloy:extent 0 0 5 (alloy:ph 1))
   :pattern colors:white)
  ((:background simple:rectangle)
   (alloy:margins)
   :pattern colors:transparent)
  ((:label simple:text)
   (alloy:margins 10 0 0 0) alloy:text
   :font (setting :display :font)
   :size (alloy:un 20)
   :halign :start
   :valign :middle))

(presentations:define-update (ui tab-button)
  (:border
   :hidden-p NIL
   :bounds (alloy:extent 0 0 (if (alloy:active-p alloy:renderable) 5.0 0.0) (alloy:ph 1)))
  (:background
   :pattern (cond ((eql :weak alloy:focus)
                   (if (eql :strong (alloy:focus (alloy:focus-parent alloy:renderable)))
                       (colored:color 0.5 0.5 0.5)
                       (colored:color 0.2 0.2 0.2)))
                  (T (if (alloy:active-p alloy:renderable)
                         (colored:color 0.3 0.3 0.3)
                         colors:transparent))))
  (:label
   :pattern (if (alloy:active-p alloy:renderable)
                colors:white
                (colored:color 0.5 0.5 0.5))))

(presentations:define-animated-shapes tab-button
  (:label (simple:pattern :duration 0.2))
  (:border (simple:bounds :duration 0.2))
  (:background (simple:pattern :duration 0.2)))

(defclass tab (tab-button)
  ((tab-view :initarg :tab-view :accessor tab-view)
   (alloy:focus-element :initform NIL :accessor alloy:focus-element)
   (alloy:layout-element :initform NIL :accessor alloy:layout-element)))

(defmethod alloy:enter ((tab tab) (view tab-view) &key)
  (setf (tab-view tab) view)
  (alloy:enter tab (alloy:focus-element view)))

(defmethod alloy:enter ((element alloy:element) (button tab) &key)
  (when (typep element 'alloy:focus-element)
    (setf (alloy:focus-element button) element)
    (when (alloy:focus-tree button)
      (alloy::set-focus-tree element (alloy:focus-tree button))))
  (when (typep element 'alloy:layout-element)
    (setf (alloy:layout-element button) element)
    (when (alloy:layout-tree button)
      (alloy::set-layout-tree element (alloy:layout-tree button)))))

(defmethod alloy::set-focus-tree :before (value (item tab))
  (when (alloy:focus-element item)
    (alloy::set-focus-tree value (alloy:focus-element item))))

(defmethod alloy::set-layout-tree :before (value (item tab))
  (when (alloy:layout-element item)
    (alloy::set-layout-tree value (alloy:layout-element item))))

(defmethod alloy:notice-focus (sub (item tab)))
(defmethod alloy:notice-size (sub (item tab)))

(defmethod alloy:register :after ((item tab) (renderer alloy:renderer))
  (when (alloy:layout-element item)
    (alloy:register (alloy:layout-element item) renderer)))

(defmethod alloy:activate ((button tab))
  (harmony:play (// 'sound 'ui-focus-in) :reset T)
  (when (alloy:layout-element button)
    (let ((layout (layout (tab-view button))))
      (when (alloy:index-element :center layout)
        (alloy:leave (alloy:index-element :center layout) layout))
      (alloy:enter (alloy:layout-element button) layout)))
  (when (alloy:focus-element button)
    (setf (alloy:focus (alloy:focus-element button)) :strong)))

(defmethod (setf alloy:focus) :after ((value (eql :weak)) (button tab))
  (unless (eql +input-source+ :keyboard)
    (when (alloy:layout-element button)
      (let ((layout (layout (tab-view button))))
        (when (alloy:index-element :center layout)
          (alloy:leave (alloy:index-element :center layout) layout))
        (alloy:enter (alloy:layout-element button) layout)))))

(defmethod (setf alloy:focus) :after ((value (eql :strong)) (button tab))
  (when (alloy:layout-element button)
    (let ((layout (layout (tab-view button))))
      (when (alloy:index-element :center layout)
        (alloy:leave (alloy:index-element :center layout) layout))
      (alloy:enter (alloy:layout-element button) layout)))
  (setf (alloy:focus (alloy:focus-element (tab-view button))) :strong))

(defclass setting-label (alloy:label)
  ())

(presentations:define-realization (ui setting-label)
  ((:label simple:text)
   (alloy:margins 0)
   alloy:text
   :font (setting :display :font)
   :wrap T
   :size (alloy:un 12)
   :halign :start
   :valign :middle))

(presentations:define-update (ui setting-label)
  (:label
   :size (alloy:un 15)))

(defclass task-widget (label)
  ())

(presentations:define-realization (ui task-widget)
  ((:indicator simple:polygon)
   (list (alloy:point 0 5)
         (alloy:point 0 15)
         (alloy:point 5 10))
   :pattern colors:white)
  ((:label simple:text)
   (alloy:margins 10 -5 5 -5)
   alloy:text
   :valign :middle
   :wrap T
   :size (alloy:un 15)
   :font (setting :display :font)))

(defclass quest-widget (alloy:vertical-linear-layout alloy:focus-element alloy:observable alloy:renderable)
  ((alloy:cell-margins :initform (alloy:margins 10 5 5 5))
   (alloy:min-size :initform (alloy:size 10 10))
   (quest :initarg :quest :accessor quest)
   (offset :initform (alloy:point 0 0) :accessor offset)))

(defmethod initialize-instance :after ((widget quest-widget) &key quest)
  (let ((header (make-instance 'label :value (quest:title quest) :style `((:label :size ,(alloy:un 20)))))
        (description (make-instance 'label :value (quest:description quest) :style `((:label :size ,(alloy:un 15) :valign :top)))))
    (alloy:enter header widget)
    (alloy:enter description widget)
    (dolist (task (quest:active-tasks quest))
      (when (visible-p task)
        (alloy:enter (make-instance 'task-widget :value (quest:title task)) widget)))))

(defmethod alloy:render :around ((renderer simple:renderer) (widget quest-widget))
  (simple:with-pushed-transforms (renderer)
    (when (alloy:focus widget)
      (simple:translate renderer (offset widget)))
    ;; KLUDGE: don't know why this is necessary...
    (alloy:reset-visibility renderer)
    (call-next-method)))

(animation:define-animation focus-in
  0 ((setf offset) (alloy:point 0 0))
  0.1 ((setf offset) (alloy:point 10 0)))

(defmethod (setf alloy:focus) :after (focus (widget quest-widget))
  (alloy:mark-for-render widget)
  (cond (focus
         (alloy:ensure-visible widget T)
         (animation:apply-animation 'focus-in widget)))
  (when (eql :strong focus)
    (setf (alloy:focus (alloy:focus-parent widget)) :strong)))

(presentations:define-realization (ui quest-widget)
  ((:bg simple:rectangle)
   (alloy:margins))
  ((:bord simple:rectangle)
   (alloy:extent 2 0 -5 (alloy:ph 1))
   :pattern (ecase (quest:status (quest alloy:renderable))
              (:inactive colors:transparent)
              (:active colors:accent)
              (:complete colors:dim-gray)
              (:failed colors:dark-red)))
  ((check simple:text)
   (alloy:margins 10)
   (ecase (quest:status (quest alloy:renderable))
     (:inactive "")
     (:active (@ quest-active-tag))
     (:complete (@ quest-complete-tag))
     (:failed (@ quest-failed-tag)))
   :pattern (colored:color 1 1 1 0.15)
   :size (alloy:un 30)
   :font "PromptFont"
   :halign :end
   :valign :bottom))

(presentations:define-update (ui quest-widget)
  (:bg
   :pattern (ecase (quest:status (quest alloy:renderable))
              (:inactive colors:transparent)
              (:active (colored:color 0.15 0.15 0.15))
              (:complete (colored:color 0.15 0.15 0.15 0.5))
              (:failed (colored:color 0.5 0.1 0.1 0.5))))
  (check))

(defclass status-text (label)
  ())

(presentations:define-realization (ui status-text)
  ((:label simple:text)
   (alloy:margins 0)
   alloy:text
   :font "NotoSansMono"
   :wrap T
   :size (alloy:un 30)
   :halign :start
   :valign :top))

(defclass item-icon (alloy:direct-value-component alloy:icon)
  ())

(presentations:define-realization (ui item-icon)
  ((icon simple:icon)
   (alloy:margins 5)
   (// 'kandria 'placeholder)))

(presentations:define-update (ui item-icon)
  (icon
   :bounds (if alloy:value
               (let ((ratio (/ (vx (size alloy:value)) (vy (size alloy:value)))))
                 (cond ((< 1 ratio)
                        (let* ((ph (alloy:to-px (alloy:ph)))
                               (h (/ ph ratio)))
                          (alloy:px-extent 0 (* (- ph h) 0.5) (alloy:pw) h)))
                       ((< ratio 1)
                        (let* ((pw (alloy:to-px (alloy:pw)))
                               (w (* pw ratio)))
                          (alloy:px-extent (* (- pw w) 0.5) 0 w (alloy:ph))))
                       (T
                        (alloy:margins))))
               (alloy:px-extent))
   :image (if alloy:value
              (texture alloy:value)
              (// 'kandria 'placeholder))
   :size (if alloy:value
             (alloy:px-size (/ (width (texture alloy:value))
                               (vx (size alloy:value)))
                            (/ (height (texture alloy:value))
                               (vy (size alloy:value))))
             (alloy:size 0 0))
   :shift (if alloy:value
              (alloy:px-point (/ (vx (offset alloy:value)) (width (texture alloy:value)))
                              (/ (vy (offset alloy:value)) (height (texture alloy:value))))
              (alloy:point 0 0))))

(defclass lore-text (label)
  ())

(presentations:define-realization (ui lore-text)
  ((background simple:rectangle)
   (alloy:margins)
   :pattern (simple:request-gradient alloy:renderer 'simple:linear-gradient
                                     (alloy:px-point 0 0)
                                     (alloy:px-point 0 100)
                                     #((0.2 #.(colored:color 0.1 0.1 0.1 0.9))
                                       (1.0 #.(colored:color 0.1 0.1 0.1 0.5)))))
  ((border simple:rectangle)
   (alloy:margins)
   :pattern colors:black
   :line-width (alloy:un 1))
  ((label simple:text)
   (alloy:margins 10 0)
   alloy:text
   :pattern colors:white
   :font (setting :display :font)
   :halign :middle
   :valign :top
   :size (alloy:un 16)
   :wrap T))

(presentations:define-update (ui lore-text)
  (label))

(defclass lore-panel (menuing-panel)
  ())

(defmethod initialize-instance :after ((panel lore-panel) &key item)
  (let* ((layout (make-instance 'eating-constraint-layout
                                :shapes (list (make-basic-background))))
         (focus (make-instance 'alloy:focus-list))
         (clipper (make-instance 'alloy:clip-view :limit :x :shapes (list (simple:rectangle (unit 'ui-pass T) (alloy:margins) :pattern (colored:color 0 0 0 0.5)))))
         (scroll (alloy:represent-with 'alloy:y-scrollbar clipper :focus-parent focus))
         (text (make-instance 'lore-text :value (if (setting :gameplay :display-swears)
                                                    (item-lore item)
                                                    (replace-swears (item-lore item))))))
    (alloy:enter text clipper)
    (alloy:enter clipper layout :constraints `((:width 800) (:required (<= 20 :l) (<= 20 :r)) (:center :w) (:bottom 100) (:top 100)))
    (alloy:enter scroll layout :constraints `((:width 20) (:right-of ,clipper 0) (:bottom 100) (:top 100)))
    (alloy:enter (make-instance 'item-icon :value item) layout
                 :constraints `((:left-of ,clipper 10) (:align :top ,clipper) (:size 100 100)))
    (alloy:enter (make-instance 'label :value (title item)) layout :constraints `((:left 50) (:above ,clipper 10) (:size 500 50)))
    (let ((back (make-instance 'button :value (@ go-backwards-in-ui) :on-activate (lambda () (hide panel)))))
      (alloy:enter back layout :constraints `((:left 50) (:below ,clipper 10) (:size 200 50)))
      (alloy:enter back focus)
      (alloy:on alloy:exit (focus)
        (setf (alloy:focus focus) :strong)
        (setf (alloy:focus back) :weak)))
    (alloy:finish-structure panel layout focus)))

(defclass unlock-button (item-icon)
  ((inventory :initarg :inventory :accessor inventory)))

(presentations:define-realization (ui unlock-button T)
  ((:border simple:rectangle)
   (alloy:margins -4)
   :line-width (alloy:un 3)
   :pattern colors:gray)
  ((:text simple:text)
   (alloy:extent (alloy:pw -0.5) -18 (alloy:pw 2) (alloy:ph 1))
   (if (item-unlocked-p alloy:value (inventory alloy:renderable))
       (title alloy:value)
       (language-string 'unknown-lore-item))
   :wrap T
   :pattern colors:white
   :font (setting :display :font)
   :size (alloy:un 12)
   :valign :bottom
   :halign :middle))

(presentations:define-update (ui unlock-button)
  (:border
   :z-index 0
   :pattern (if (item-unlocked-p alloy:value (inventory alloy:renderable))
                (if alloy:focus colors:accent colors:white)
                (if alloy:focus colors:gray colors:black)))
  (icon
   :rotation (float (/ PI -2) 0f0)
   :pivot (alloy:point (alloy:ph 0.5) (alloy:ph 0.5))
   :composite-mode (if (item-unlocked-p alloy:value (inventory alloy:renderable))
                       :source-over
                       :clear))
  (:text
   :hidden-p (not alloy:focus)))

(defmethod alloy:activate ((button unlock-button))
  (if (item-unlocked-p (alloy:value button) (inventory button))
      (when (item-lore (alloy:value button))
        (show (make-instance 'lore-panel :item (alloy:value button))))
      (harmony:play (// 'sound 'ui-error) :reset T)))

(defmethod (setf alloy:focus) :before (focus (button unlock-button))
  (when (item-unlocked-p (alloy:value button) (inventory button))
    (when (and (eql NIL focus) (alloy:focus button))
      (alloy:do-elements (el (alloy:popups (alloy:layout-tree (unit 'ui-pass T))))
        (when (typep el 'prompt)
          (hide el)
          (return))))))

(defclass menu (pausing-panel menuing-panel)
  ())

(defmethod handle ((ev tick) (menu menu))
  )

(defmethod show :before ((menu menu) &key)
  (harmony:play (// 'sound 'ui-open-menu) :reset T)
  (clear-retained)
  (hide (unit 'walkntalk T)))

(defmethod show :after ((menu menu) &key)
  (alloy:activate (alloy:focus-element menu)))

(defmethod hide :after ((menu menu))
  (harmony:play (// 'sound 'ui-close-menu) :reset T))

(defmethod initialize-instance :after ((panel menu) &key)
  (let ((layout (make-instance 'menu-layout))
        (tabs (make-instance 'tab-view)))
    (alloy:on alloy:exit ((alloy:focus-element tabs))
      (hide panel))
    (alloy:enter tabs layout :place :center)
    (macrolet ((with-tab ((name layout &optional (focus ''vertical-menu-focus-list)) &body body)
                 `(let* ((layout (make-instance ,layout))
                         (focus (make-instance ,focus)))
                    ,@body
                    (add-tab tabs ,name layout focus)))
               (with-tab-view (name &body body)
                 `(let* ((view (make-instance 'tab-view))
                         (tab (add-tab tabs ,name (alloy:layout-element view) (alloy:focus-element view)))
                         (tabs view))
                    (declare (ignore tab))
                    ,@body))
               (with-button (name &body body)
                 `(make-instance 'button :value (@ ,name) :on-activate (lambda () ,@body) :focus-parent focus)))
      (with-tab ((@ overview-menu) 'org.shirakumo.alloy.layouts.constraint:layout
                 'overview-focus-list)
        (setf (alloy:wrap-focus focus) NIL)
        (let ((resume (with-button resume-game (hide panel)))
              (map (with-button open-map (show-panel 'map-panel)))
              (buttons (make-instance 'alloy:horizontal-linear-layout :min-size (alloy:size 200 40)))
              (status (make-instance 'alloy:grid-layout :col-sizes '(300 T) :row-sizes '(40) :cell-margins (alloy:margins -10)))
              (player (unit 'player +world+))
              (long-play-time-limit (* 60 60 4)))
          (flet ((add (label value &rest args)
                   (alloy:enter (make-instance 'label :value label) status)
                   (alloy:enter (apply #'make-instance 'label :value value args) status)))
            (add (@ player-health) (format NIL "~a / ~a (~a%)"
                                           (truncate (health player))
                                           (truncate (maximum-health player))
                                           (health-percentage player)))
            (add (@ player-level-count) (princ-to-string (level player)))
            (add (@ player-experience-points) (format NIL "~a / ~a" (experience player) (exp-needed-for-level (level player))))
            (add (@ distance-travelled) (format NIL "~,2fm" (/ (stats-distance (stats player)) 16)))
            (add (@ in-game-datetime) (format-absolute-time (truncate (timestamp +world+))))
            (add (@ current-play-time) (format NIL "~a~@[ ~a~]"
                                               (format-relative-time (session-time))
                                               (when (< long-play-time-limit (session-time)) (@ long-play-time-warning)))
                 :style (when (< long-play-time-limit (session-time)) `((:label  :pattern ,colors:red))))
            (add (@ total-play-time) (format-relative-time (total-play-time))))
          (alloy:enter status layout :constraints `(:center (:required (<= 100 :l)) (:size 1000 350)))
          (alloy:enter buttons layout :constraints `((:chain :down ,status 10) (:height 40)))
          (alloy:enter resume buttons)
          (alloy:enter map buttons)
          (when (and (saving-possible-p)
                     (save-point-available-p))
            (let ((save (with-button save-game
                          (save-state +main+ T)
                          (harmony:play (// 'sound 'ui-confirm) :reset T))))
              (alloy:enter save buttons)))))

      (with-tab ((@ quest-menu) 'alloy:border-layout)
        (let* ((list (make-instance 'alloy:vertical-linear-layout :cell-margins (alloy:margins 2 10 2 2)))
               (clipper (make-instance 'alloy:clip-view :limit :x :layout-parent layout))
               (scroll (alloy:represent-with 'alloy:y-scrollbar clipper)))
          (alloy:enter list clipper)
          (alloy:enter scroll layout :place :east :size (alloy:un 20))
          (dolist (quest (sort (copy-list (quest:known-quests (storyline +world+)))
                               (lambda (a b)
                                 (flet ((status-precedence (a)
                                          (case (quest:status a)
                                            (:inactive 100)
                                            (:active -100)
                                            (T 0))))
                                   (if (eq (quest:status a) (quest:status b))
                                       (> (start-time a) (start-time b))
                                       (< (status-precedence a) (status-precedence b)))))))
            (unless (or (eq :inactive (quest:status quest))
                        (not (visible-p quest)))
              (let ((widget (make-instance 'quest-widget :quest quest)))
                (alloy:enter widget list)
                (alloy:enter widget focus))))))

      (let ((inventory (unit 'player T)))
        (with-tab-view (@ inventory-menu)
          (dolist (category '(consumable-item quest-item value-item special-item))
            (with-tab ((language-string category) 'alloy:border-layout)
              (let* ((list (make-instance 'alloy:vertical-linear-layout :min-size (alloy:size 300 50)))
                     (clipper (make-instance 'alloy:clip-view :limit :x :layout-parent layout))
                     (scroll (alloy:represent-with 'alloy:y-scrollbar clipper))
                     (info (make-instance 'alloy:border-layout :padding (alloy:margins 10)
                                                               :shapes (list (simple:rectangle (unit 'ui-pass T) (alloy:extent 0 (alloy:ph 1) (alloy:pw 1) 1) :name :top :pattern colors:white))))
                     (icon (make-instance 'item-icon :value NIL))
                     (description (make-instance 'label :layout-parent info :value ""
                                                        :style `((:label :bounds ,(alloy:margins 5)
                                                                         :size ,(alloy:un 16))))))
                (alloy:enter list clipper)
                (alloy:enter icon info :place :west :size (alloy:un 120))
                (alloy:enter info layout :place :south :size (alloy:un 120))
                (alloy:enter scroll layout :place :east :size (alloy:un 20))
                (dolist (item (list-items inventory category))
                  (let ((button (make-instance 'item-button :value item :inventory inventory)))
                    (alloy:on alloy:focus (value button)
                      (when value
                        (setf (alloy:value description) (item-description (alloy:value button)))
                        (setf (alloy:value icon) (make-instance (class-of (alloy:value button))))))
                    (alloy:enter button list)
                    (alloy:enter button focus)))))))

        (with-tab-view (@ lore-menu)
          (dolist (category '(fish lore-item))
            ;; FIXME: don't know how to navigate up/down rows due to flow layout
            (let* ((layout (make-instance 'alloy:border-layout))
                   (focus (make-instance 'alloy:focus-list))
                   (list (make-instance 'alloy:flow-layout :cell-margins (alloy:margins 20 20) :min-size (alloy:size 100)))
                   (clipper (make-instance 'alloy:clip-view :limit :x :layout-parent layout))
                   (scroll (alloy:represent-with 'alloy:y-scrollbar clipper)))
              (alloy:enter list clipper)
              (alloy:enter "" layout :place :south :size (alloy:un 20))
              (alloy:enter scroll layout :place :east :size (alloy:un 20))
              (dolist (item (list-items (c2mop:class-prototype (c2mop:ensure-finalized (find-class category))) T))
                (let ((button (make-instance 'unlock-button :value item :inventory inventory)))
                  (alloy:enter button list)
                  (alloy:enter button focus)))
              (add-tab tabs (language-string category) layout focus)))))

      (let ((view (make-instance 'options-menu)))
        (add-tab tabs (@ open-options-menu) (alloy:layout-element view) (alloy:focus-element view)))

      (flet ((exit ()
               (let ((mins (floor (- (get-universal-time) (save-time (state +main+))) 60)))
                 (when (< 60 mins)
                   (setf mins "> 60"))
                 (show (make-instance 'prompt-panel :text (@formats 'game-quit-reminder mins)
                                                    :on-accept #'return-to-main-menu)
                       :width (alloy:un 500)
                       :height (alloy:un 300)))))
        (let ((button (make-instance 'tab-button :value (@ return-to-main-menu) :focus-parent tabs)))
          (alloy:on alloy:activate (button)
            (exit)))))
    (alloy:finish-structure panel layout (alloy:focus-element tabs))))

;; FIXME: when changing language or font, UI needs to update immediately
