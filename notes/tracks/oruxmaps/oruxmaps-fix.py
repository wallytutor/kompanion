# -*- coding: utf-8 -*-
from majordome.cartography import (GpxManager, display_track)


if __name__ == "__main__":
    gpx_mgnr = GpxManager.from_file("track-orig.gpx")
    gpx_mngr = gpx_mgnr.sanitize(dump="track-sanitized.gpx")

    track_map = display_track(gpx_mngr, colored=True, vmin=750, vmax=1000)
    track_map.save("track.html")
