# Timezone and locale.
{
  lib,
  ...
}:

{
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
}
