defmodule Snitch.MyCldr do
  use Cldr,
    otp_app: :snitch_core,
    locales: ["en", "fr", "zh", "th"],
    default_locale: "en",
    providers: [Cldr.Number, Money]
end
