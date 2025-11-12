Config = {}

-- Command that opens the tablet UI.
Config.OpenCommand = 'tabletorg'

-- Key mapping suggestion for the command (can be changed in-game by players).
Config.DefaultKey = 'F10'

-- Restrict access to specific ESX jobs. Leave the table empty to allow everyone.
Config.AllowedJobs = {
  -- ['police'] = true,
  -- ['ambulance'] = true,
}

-- Database table used to persist the organization data.
Config.DatabaseTable = 'tablet_organizations'

-- Limiters and validation rules for extended tablet features.
Config.MaxMottoLength = 280
Config.MaxRecruitmentLength = 320
Config.MaxNoteLength = 480
Config.MaxFundsAdjustment = 250000
Config.MaxStoredFunds = 2000000
Config.MaxPlanEntries = 8
Config.MaxPlanLabelLength = 64

-- Discord role verification used to unlock organization creation when none exists yet.
Config.Discord = {
  GuildId = '1435216731063717922',
  RequiredRoleId = '1438145331144687837',
  BotToken = '', -- Wklej token bota Discord w to pole, aby włączyć weryfikację rangi.
  CacheDuration = 300, -- czas (w sekundach) przez jaki wynik sprawdzenia będzie pamiętany
  Timeout = 5000, -- maksymalny czas oczekiwania na odpowiedź Discord (ms)
}
