#!/usr/bin/env python3
"""Interactive polygon crop — standalone script.
Usage: python3 interactive_crop.py <input_image> <output_image>
Opens OpenCV window for mouse-based polygon selection.
Press C to complete, R to reset, Q to cancel.
"""
import cv2
import numpy as np
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: interactive_crop.py <input> <output>", file=sys.stderr)
        sys.exit(1)

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    img = cv2.imread(in_path)
    if img is None:
        print(f"Cannot read: {in_path}", file=sys.stderr)
        sys.exit(1)

    clone = img.copy()
    points = []
    win = "Crop - click points, press C to finish, R reset, Q quit"

    def mouse_callback(event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            points.append([x, y])
            cv2.circle(clone, (x, y), 5, (0, 255, 0), -1)
            cv2.imshow(win, clone)
            if len(points) > 2:
                temp = clone.copy()
                cv2.polylines(temp, [np.array(points, np.int32)], True, (0, 255, 0), 2)
                cv2.imshow(win, temp)

    cv2.namedWindow(win)
    cv2.setMouseCallback(win, mouse_callback)
    cv2.imshow(win, clone)
    cv2.waitKey(1)

    while True:
        key = cv2.waitKey(30) & 0xFF
        if key == ord('c') and len(points) >= 3:
            pts = np.array(points, np.int32)
            mask = np.zeros(img.shape[:2], dtype=np.uint8)
            cv2.fillPoly(mask, [pts], 255)
            result = cv2.bitwise_and(img, img, mask=mask)
            b, g, r = cv2.split(result)
            rgba = cv2.merge([b, g, r, mask])
            cv2.imwrite(out_path, rgba)
            print(f"Cropped saved: {out_path}")
            break
        elif key == ord('r'):
            points.clear()
            clone = img.copy()
            cv2.imshow(win, clone)
        elif key == ord('q'):
            break

    cv2.destroyAllWindows()
    cv2.waitKey(1)

if __name__ == "__main__":
    main()
