(function(){
  function init(){
    var nav=document.querySelector('header ul.nav');
    if(!nav) return;
    var map={
      'Status':'System Status',
      'Network':'General Settings',
      'System':'Advanced Settings'
    };
    Array.prototype.forEach.call(nav.querySelectorAll(':scope > li > a'),function(a){
      var t=(a.textContent||'').trim();
      if(map[t]) a.textContent=map[t];
    });
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init);
  else init();
})();