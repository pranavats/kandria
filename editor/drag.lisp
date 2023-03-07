(in-package #:org.shirakumo.fraf.kandria)

(define-shader-entity drag-sentinel (vertex-entity colored-entity located-entity standalone-shader-entity dynamic-renderable)
  ((vertex-array :initform (// 'kandria '1x))
   (color :initform (vec 1 0 0 0.5))
   (bsize :initarg :bsize :initform (nv/ (vec +tile-size+ +tile-size+) 2) :accessor bsize
          :type vec2 :documentation "The bounding box half size.")))

(defmethod apply-transforms progn ((sentinel drag-sentinel))
  (let ((size (bsize sentinel)))
    (translate-by (- (vx size)) (- (vy size)) 100)
    (scale-by (* 2 (vx size)) (* 2 (vy size)) 1)))

(defmethod layer-index ((sentinel drag-sentinel)) 100)

(defmethod scan ((entity drag-sentinel) (target vec2) on-hit)
  (let ((w (vx2 (bsize entity)))
        (h (vy2 (bsize entity)))
        (loc (location entity)))
    (when (and (<= (- (vx2 loc) w) (vx2 target) (+ (vx2 loc) w))
               (<= (- (vy2 loc) h) (vy2 target) (+ (vy2 loc) h)))
      (let ((hit (make-hit entity (location entity))))
        (unless (funcall on-hit hit) hit)))))

(defclass drag (tool)
  ((sentinel :initform (make-instance 'drag-sentinel) :accessor sentinel)
   (start-pos :initform (vec 0 0) :accessor start-pos)
   (offset :initform (vec 0 0) :accessor offset)
   (layer :initform NIL :accessor layer)
   (stencil :initform #((())) :accessor stencil)
   (cache :initform #() :accessor cache)))

(defmethod label ((tool drag)) "")
(defmethod title ((tool drag)) "Drag (D)")

(defmethod (setf tool) :after ((tool drag) (editor editor))
  (enter (sentinel tool) (region +world+)))

(defmethod stage ((tool drag) (area staging-area))
  (stage (sentinel tool) area))

(defmethod hide :after ((tool drag))
  (leave (sentinel tool) T))

(defmethod handle ((ev lose-focus) (tool drag))
  (handle (make-instance 'mouse-release :button :left :pos (or (start-pos tool) (vec 0 0))) tool))

(defmethod handle ((event mouse-press) (tool drag))
  (unless (state tool)
    (let ((pos (nvalign (mouse-world-pos (pos event)) +tile-size+))
          (sentinel (sentinel tool)))
      (setf (start-pos tool) pos)
      (cond ((and (layer tool)
                  (contained-p pos (sentinel tool)))
             (setf (state tool) :moving)
             (setf (offset tool) (v- pos (location sentinel)))
             (setf (cache tool) (copy-sentinel-to-stencil tool)))
            (T
             (setf (layer tool) (if (show-solids (entity tool))
                                    (entity tool)
                                    (aref (layers (entity tool)) (layer (sidebar (editor tool))))))
             (when (layer tool)
               (setf (state tool) :selecting)
               (setf (location (sentinel tool)) pos)
               (setf (bsize (sentinel tool)) (vec 0 0))))))))

(defun copy-sentinel-to-stencil (tool &optional (offset (vec 0 0)))
  (let ((layer (layer tool))
        (sentinel (sentinel tool)))
    (%with-layer-xy (layer (v- (v+ (location sentinel) offset) (bsize sentinel)))
      (stencil-from-map (pixel-data layer)
                        (truncate (vx2 (size layer)))
                        (truncate (vy2 (size layer)))
                        x y
                        (truncate (* 2 (vx2 (bsize sentinel))) +tile-size+)
                        (truncate (* 2 (vy2 (bsize sentinel))) +tile-size+)))))

(defmethod handle :after ((event mouse-release) (tool drag))
  (let ((layer (layer tool))
        (sentinel (sentinel tool)))
    (case (state tool)
      (:moving
       (let* ((start (start-pos tool))
              (offset (offset tool))
              (w (truncate (vx2 (size layer))))
              (h (truncate (vy2 (size layer))))
              (location (location sentinel))
              (old-location (v- start offset))
              (bsize (bsize sentinel))
              (replaced (copy-sentinel-to-stencil tool))
              (cleared (unless (retained :shift)
                         (cache tool))))
         (with-commit (tool "Drag")
           ((when cleared
              (%with-layer-xy (layer (v- old-location bsize))
                (let ((stencil-w (truncate (* 2 (vx2 bsize)) +tile-size+))
                      (stencil-h (truncate (* 2 (vy2 bsize)) +tile-size+)))
                  (set-tile-stencil (pixel-data layer) w h x y (stencil-from-fill stencil-w stencil-h)))))
            (%with-layer-xy (layer (v- location bsize))
              (set-tile-stencil (pixel-data layer) w h x y (stencil tool)))
            (setf (bsize sentinel) bsize)
            (setf (location sentinel) location)
            (update-layer layer))
           ((%with-layer-xy (layer (v- location bsize))
              (set-tile-stencil (pixel-data layer) w h x y replaced))
            (when cleared
              (%with-layer-xy (layer (v- old-location bsize))
                (set-tile-stencil (pixel-data layer) w h x y cleared)))
            (setf (bsize sentinel) bsize)
            (setf (location sentinel) old-location)
            (update-layer layer)))))
      (:selecting
       (setf (stencil tool) (copy-sentinel-to-stencil tool)))))
  (setf (state tool) NIL))

(defmethod handle ((event mouse-move) (tool drag))
  (let ((pos (nvalign (mouse-world-pos (pos event)) +tile-size+))
        (start (start-pos tool))
        (sentinel (sentinel tool)))
    (case (state tool)
      (:moving
       (setf (location sentinel) (v- pos (offset tool))))
      (:selecting
       (setf (bsize sentinel) (vabs (v* (v- pos start) 0.5)))
       (setf (location sentinel) (v* (v+ pos start) 0.5))))))
