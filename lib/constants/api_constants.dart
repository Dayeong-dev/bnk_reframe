// http://192.168.100.155
// 192.168.100.124 수현학원 192.168.123.107 집
// 192.168.0.238 정원

const apiUrl = "192.168.0.238";

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: "http://$apiUrl:8090",
);
