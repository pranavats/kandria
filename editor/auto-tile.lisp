(in-package #:org.shirakumo.fraf.kandria)

(defclass auto-tile (painter-tool)
  ((start-pos :initform NIL :accessor start-pos)
   (end-pos :initform NIL :accessor end-pos)))

(defmethod label ((tool auto-tile)) "")
(defmethod title ((tool auto-tile)) "Auto-Tile")

(defmethod handle ((ev lose-focus) (tool auto-tile))
  (handle (make-instance 'mouse-release :button :left :pos (or (end-pos tool) (vec 0 0))) tool))

(defmethod handle ((event mouse-release) (tool auto-tile))
  (case (state tool)
    (:placing
     (setf (state tool) NIL)
     (let ((entity (entity tool))
           (start (shiftf (start-pos tool) NIL))
           (end (shiftf (end-pos tool) NIL)))
       (cond ((= +base-layer+ (layer (sidebar (editor tool))))
              (let* ((base-layer (aref (layers entity) +base-layer+))
                     (layer (copy-seq (pixel-data base-layer))))
                (with-cleanup-on-failure (setf (pixel-data base-layer) layer)
                  (with-commit (tool "Auto-tile")
                    ((auto-tile entity (vec (min (vx end) (vx start))
                                            (min (vy end) (vy start))
                                            (abs (- (vx end) (vx start)))
                                            (abs (- (vy end) (vy start))))
                                (cdr (assoc (tile-set (sidebar (editor tool)))
                                            (tile-types (tile-data entity))))))
                    ((setf (pixel-data base-layer) layer))))))
             ((= 0 (layer (sidebar (editor tool))))
              (let* ((base-layer (aref (layers entity) 0))
                     (extra-layer (aref (layers entity) 1))
                     (layer (copy-seq (pixel-data base-layer)))
                     (layer2 (copy-seq (pixel-data base-layer))))
                (with-cleanup-on-failure (progn (setf (pixel-data base-layer) layer)
                                                (setf (pixel-data extra-layer) layer2))
                  (with-commit (tool "Auto-tile background")
                    ((%auto-tile-bg (pixel-data base-layer) (pixel-data extra-layer)
                                    (truncate (vx (size base-layer))) (truncate (vy (size base-layer)))
                                    (cdr (assoc (tile-set (sidebar (editor tool)))
                                                (tile-types (tile-data entity)))))
                     (update-layer base-layer)
                     (update-layer extra-layer))
                    ((setf (pixel-data base-layer) layer)
                     (setf (pixel-data extra-layer) layer2)))))))))))

(defmethod paint-tile ((tool auto-tile) event)
  (let* ((loc (mouse-tile-pos (pos event))))
    (setf (state tool) :placing)
    (unless (start-pos tool)
      (setf (start-pos tool) loc)
      (setf (end-pos tool) loc))
    (when (v/= (end-pos tool) loc)
      (setf (end-pos tool) loc))))
