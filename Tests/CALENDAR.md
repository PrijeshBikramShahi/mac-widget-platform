# Calendar widget

The desktop calendar defaults to English + Nepali. Choose English (AD), Nepali
(BS), or both in Settings → Widget options → Calendar → Dates. The small combined
card places the English date beneath the Nepali date; the wide card uses two
columns. The WidgetKit calendar displays both dates in its small and medium sizes.
Desktop settings are app-local, so they do not change the WidgetKit extension.

Nepali and combined modes use Asia/Kathmandu for both calendars and the weekday.
English-only mode uses the Mac's time zone. Desktop cards refresh every minute;
WidgetKit schedules its next entry at Nepal midnight.

## Offline conversion data

`Shared/BikramSambatData.swift` contains month lengths from
[py-nepali](https://github.com/opensource-nepal/py-nepali/blob/3ff19477150ea597d6ce2e9d3dce62e6cf0065e6/nepali/date_converter.py),
pinned to commit `3ff19477150ea597d6ce2e9d3dce62e6cf0065e6`. Its MIT license is
included in that source file. Conversion starts at BS 2000-01-01 / AD 1943-04-14
and ends at BS 2099-12-30 / AD 2043-04-13. Outside that interval the view shows
the English date and “BS unavailable”. No network access is needed at runtime.

Future year tables may be revised; this is a bundled conversion table, not a
guarantee of future officially published calendars. Check newer published
calendars when updating the data. Today's reference pair (2026-10-15 /
2083-06-29) and the October 18 month rollover were cross-checked against
[Ramro Patro](https://ramropatro.com/calendar/2083/ashoj).

## Verification

Run `sh Tests/run.sh`. Calendar checks cover fixed reference pairs, BS new year,
month ends, range limits, Nepali numerals, Nepal midnight, and continuous daily
conversion across the 36,525 supported days (including Nepal's historical time
zone change). Continuous traversal verifies conversion mechanics against the
bundled table; it does not independently certify every table entry.

Build both targets with:

```sh
xcodebuild -project Widgion.xcodeproj -scheme Widgion -configuration Debug \
  -derivedDataPath /tmp/widgion-calendar-build CODE_SIGNING_ALLOWED=NO build
```
