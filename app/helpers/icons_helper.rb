# frozen_string_literal: true

# Inline SVG icons, from Lucide (https://lucide.dev, MIT).
#
# Inline rather than an icon font or a CDN sheet: six icons are smaller than
# the request that would fetch them, they inherit `currentColor` so they take
# the theme with no extra styling, and the page keeps working with no third
# party involved.
module IconsHelper
  # Every path here is drawn on Lucide's 24x24 grid with no fill, so they all
  # line up at any size.
  ICONS = {
    ruler: [
      "M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z",
      "m14.5 12.5 2-2",
      "m11.5 9.5 2-2",
      "m8.5 6.5 2-2",
      "m17.5 15.5 2-2"
    ],
    weight: [
      "M6.5 8a2 2 0 0 0-1.905 1.46L2.1 18.5A2 2 0 0 0 4 21h16a2 2 0 0 0 1.925-2.54L19.4 9.46A2 2 0 0 0 17.48 8Z",
      "M12 2a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z"
    ],
    heart_pulse: [
      "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z",
      "M3.22 13H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27"
    ],
    activity: [
      "M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2"
    ],
    mars: [
      "M16 3h5v5",
      "m21 3-6.75 6.75",
      "M10 20a6 6 0 1 0 0-12 6 6 0 0 0 0 12Z"
    ],
    venus: [
      "M12 15v7",
      "M9 19h6",
      "M12 15a6 6 0 1 0 0-12 6 6 0 0 0 0 12Z"
    ]
  }.freeze

  # `label` turns an icon into something a screen reader announces; without one
  # it is decoration and stays hidden.
  def icon(name, label: nil, css_class: nil)
    paths = ICONS.fetch(name.to_sym)

    tag.svg(
      safe_join(paths.map { |path| tag.path(d: path) }),
      class: css_class,
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 2,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      role: label ? "img" : nil,
      "aria-label": label,
      "aria-hidden": label ? nil : true
    )
  end
end
