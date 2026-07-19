{
  services.keyd = {
    enable = true;

    keyboards.external75 = {
      ids = [
        "342d:e485:4e2f5f07"
        "342d:e485:042e7344"
      ];

      settings = {
        main = {
          pagedown = "end";
          pageup = "print";
        };
      };
    };
  };
}
