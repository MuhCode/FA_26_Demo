-- Player profile table for tracking stats and achievement flags
CREATE TABLE IF NOT EXISTS player_profile (
    player_id VARCHAR(50) PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL DEFAULT 'commander_fa26',
    enemies_killed INT NOT NULL DEFAULT 0,
    battles_won INT NOT NULL DEFAULT 0,
    games_finished INT NOT NULL DEFAULT 0,
    flag_first_battle BOOLEAN NOT NULL DEFAULT FALSE,
    flag_ten_battles BOOLEAN NOT NULL DEFAULT FALSE,
    flag_game_finished BOOLEAN NOT NULL DEFAULT FALSE,
    last_action VARCHAR(50) DEFAULT 'INIT',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Default test player for the demo
INSERT INTO player_profile (player_id, display_name)
VALUES ('commander_fa26', 'commander_fa26')
ON CONFLICT (player_id) DO NOTHING;
