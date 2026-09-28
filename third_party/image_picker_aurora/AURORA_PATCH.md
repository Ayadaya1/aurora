# Camera failure handling

Vendored from the official Aurora pub repository, image_picker_aurora 2.4.0:
https://sdk-repo.omprussia.ru/sdk/flutter/pub/
Original LICENSE.txt and source notices are preserved.

Upstream leaves the camera dialog loading indefinitely when availableCameras
returns no supported camera, with an unhandled initialization exception.
The patch displays an error and a Close button, also available while loading.
It handles camera switching/capture failures, releases the CameraController
on disposal and checks mounted after asynchronous operations.

Only Aurora builds apply this override (tools/build-aurora.sh).
