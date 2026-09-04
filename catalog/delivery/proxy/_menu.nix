# Menu node: Web Proxy
{ bodies }:
{
  order = 1;
  menuName = "Web Proxy";
  label = "Web Proxy";
  directory = "annixion-3-delivery-proxy.directory";
  category = "X-AnNIXion-Delivery-Proxy";
  mark = {
    class = "offensive";
    body = bodies.burpsuite;
    over = bodies.burpsuiteOver;
  };
}
