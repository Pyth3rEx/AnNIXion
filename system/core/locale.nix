# Timezone and locale.
{
  lib,
  ...
}:

{
  time.timeZone = lib.mkDefault "Europe/Paris";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
}
