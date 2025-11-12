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
