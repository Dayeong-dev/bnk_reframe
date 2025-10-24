const apiUrl = "[아이피 주소 입력란]";

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: "http://$apiUrl:8090",
);
