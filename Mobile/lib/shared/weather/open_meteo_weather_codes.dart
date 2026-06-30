/// WMO weather codes from Open-Meteo → OpenWeather-style labels for existing UI rules.
class OpenMeteoWeatherCodes {
  static String weatherMain(int code) {
    if (code == 0) return 'Clear';
    if (code >= 1 && code <= 3) return 'Clouds';
    if (code == 45 || code == 48) return 'Mist';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return 'Rain';
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return 'Snow';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Clouds';
  }

  static String description(int code) {
    return switch (code) {
      0 => 'clear sky',
      1 => 'mainly clear',
      2 => 'partly cloudy',
      3 => 'overcast',
      45 => 'fog',
      48 => 'depositing rime fog',
      51 || 53 || 55 => 'drizzle',
      56 || 57 => 'freezing drizzle',
      61 || 63 || 65 => 'rain',
      66 || 67 => 'freezing rain',
      71 || 73 || 75 => 'snow',
      77 => 'snow grains',
      80 || 81 || 82 => 'rain showers',
      85 || 86 => 'snow showers',
      95 => 'thunderstorm',
      96 || 99 => 'thunderstorm with hail',
      _ => 'cloudy',
    };
  }
}
