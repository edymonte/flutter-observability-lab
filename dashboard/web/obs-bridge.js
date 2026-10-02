// Ponte entre o Flutter Web e o Datadog Browser RUM.
// No app mobile real, esse papel é do datadog_flutter_plugin (que no web usa este mesmo SDK).
(function () {
  var cfg = window.OBS_CONFIG || {};
  var site = cfg.site || 'datadoghq.com';
  var state = { rumEnabled: false, rumLoaded: false, error: null };

  var regionBySite = {
    'datadoghq.com': 'us1',
    'us3.datadoghq.com': 'us3',
    'us5.datadoghq.com': 'us5',
    'datadoghq.eu': 'eu1',
    'ap1.datadoghq.com': 'ap1',
    'ap2.datadoghq.com': 'ap2',
    'ddog-gov.com': 'us1'
  };
  var appUrl =
    site === 'datadoghq.com' ? 'https://app.datadoghq.com' :
    site === 'datadoghq.eu' ? 'https://app.datadoghq.eu' :
    'https://' + site;

  if (cfg.rumApplicationId && cfg.rumClientToken) {
    state.rumEnabled = true;
    var s = document.createElement('script');
    s.src = 'https://www.datadoghq-browser-agent.com/' + (regionBySite[site] || 'us1') + '/v5/datadog-rum.js';
    s.async = true;
    s.onload = function () {
      try {
        window.DD_RUM.init({
          applicationId: cfg.rumApplicationId,
          clientToken: cfg.rumClientToken,
          site: site,
          service: cfg.rumService || 'loja-app-pagamento-web',
          env: cfg.env || 'lab',
          version: cfg.version || '0.1.0',
          sessionSampleRate: 100,
          sessionReplaySampleRate: 0,
          trackUserInteractions: true,
          trackResources: true,
          trackLongTasks: true,
          defaultPrivacyLevel: 'mask-user-input',
          // Equivalente ao firstPartyHosts do datadog_flutter_plugin:
          // injeta headers de trace nas chamadas ao BFF para ligar RUM -> APM.
          allowedTracingUrls: [{
            match: function (url) { return url.indexOf(window.location.origin + '/api/v1/pagamento') === 0; },
            propagatorTypes: ['datadog', 'tracecontext']
          }],
          traceSampleRate: 100
        });
        window.DD_RUM.setGlobalContextProperty('journey.name', 'pagamento');
        state.rumLoaded = true;
      } catch (e) { state.error = String(e); }
    };
    s.onerror = function () { state.error = 'Falha ao carregar o SDK do RUM (rede/proxy?)'; };
    document.head.appendChild(s);
  }

  window.obsBridge = {
    info: function () {
      var sid = null;
      try {
        var c = window.DD_RUM && window.DD_RUM.getInternalContext && window.DD_RUM.getInternalContext();
        sid = c ? c.session_id : null;
      } catch (e) { /* ignore */ }
      return JSON.stringify({
        rumEnabled: state.rumEnabled, rumLoaded: state.rumLoaded, rumSessionId: sid,
        site: site, appUrl: appUrl, env: cfg.env || 'lab', error: state.error
      });
    },
    addAction: function (name, attrsJson) {
      try { if (state.rumLoaded) window.DD_RUM.addAction(name, JSON.parse(attrsJson)); } catch (e) { /* ignore */ }
    },
    addError: function (message, attrsJson) {
      try { if (state.rumLoaded) window.DD_RUM.addError(new Error(message), JSON.parse(attrsJson)); } catch (e) { /* ignore */ }
    },
    setContext: function (key, value) {
      try { if (state.rumLoaded) window.DD_RUM.setGlobalContextProperty(key, value); } catch (e) { /* ignore */ }
    },
    open: function (url) { window.open(url, '_blank', 'noopener'); }
  };
})();
