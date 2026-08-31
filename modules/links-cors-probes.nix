{
  headers = ''
    add_header Access-Control-Allow-Origin "https://links.house.leo.surf" always;
    add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Accept, Authorization, Content-Type, Origin, Range" always;
    add_header Access-Control-Allow-Private-Network "true" always;
    add_header Vary "Origin" always;
  '';

  methodMap = ''
    map $request_method $links_probe_proxy_method {
      HEAD GET;
      default $request_method;
    }
  '';

  hideUpstreamHeaders = ''
    proxy_hide_header Access-Control-Allow-Origin;
    proxy_hide_header Access-Control-Allow-Methods;
    proxy_hide_header Access-Control-Allow-Headers;
    proxy_hide_header Access-Control-Allow-Private-Network;
  '';

  proxyMethod = ''
    proxy_method $links_probe_proxy_method;
  '';
}
