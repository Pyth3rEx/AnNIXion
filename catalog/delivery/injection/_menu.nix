# Menu node: Web Injection
{ bodies }:
{
  order = 2;
  menuName = "Web Injection";
  label = "Web Injection";
  directory = "annixion-3-delivery-injection.directory";
  category = "X-AnNIXion-Delivery-Injection";
  mark = {
    class = "offensive";
    body = ''
      <path d="M3.3 5.2c0-1.7 3.4-3 7.5-2.9 4 0 7.3 1.3 7.3 3s-3.4 2.9-7.4 2.9-7.4-1.3-7.4-3z"/>
      <path d="M3.3 5.2q-.2 5.3 0 10.6c0 1.7 3.3 2.9 7.4 2.9 1 0 2 0 3-.2"/>
      <path d="M18.1 5.3q.2 2.8 0 5.6"/>
    '';
    over = bodies.sqlmapOver;
  };
}
