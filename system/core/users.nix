# The operator account and the groups a desktop session needs.
{
  lib,
  ...
}:

{
  users.users.operator = {
    isNormalUser = lib.mkDefault true;
    extraGroups = lib.mkDefault [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    hashedPassword = lib.mkDefault "$6$DkRVwYEQPe/aYDUp$ULU/oBw9ujsQa5.s4EgWKL2YNNZ2SmEfA0PrMqF6XrZ.FCOsplXdTTEPsWmFH1dU0tB0/JRHeSxasjPBBuQAu1";
  };
}
