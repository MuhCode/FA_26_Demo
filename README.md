# Armies of Many Fates - FA26 Demo

Prototype connecting a Godot 4 Client UI over the internet through a Cloudflare Tunnel to a dedicated Godot Server and PostgreSQL database.

## Project Structure

- `godot_poc/ClientUI.tscn` & `ClientUI.gd` - Client UI (runs on the player's machine, sends HTTP `POST` and `GET` requests)
- `godot_poc/Server.tscn` & `Server.gd` - Dedicated Server (listens on port `8080`, holds active battle state, and queries PostgreSQL)
- `cloudflare/config.yml` - Cloudflare Tunnel config (routes traffic to `http://127.0.0.1:8080` with debug logging)
- `db/init.sql` - SQL setup for the `player_profile` table and default player row
- `start_cloudflare.bat` - Starts PostgreSQL, opens `pgAdmin 4`, launches the headless Godot Server (`Server.tscn`), and starts the Cloudflare Tunnel

---

## First-Time Laptop Setup

### 1. Install Prerequisites (PowerShell)

Install PostgreSQL 17 (which includes `pgAdmin 4`) and Cloudflare Tunnel:

```powershell
winget install PostgreSQL.PostgreSQL.17
winget install Cloudflare.cloudflared
```

> **Note:** When the PostgreSQL installer asks for a password for the `postgres` user, set it to **`postgres`** (all lowercase) to match `db_password` in `Server.gd`.

### 2. Initialize the Database in `pgAdmin 4`

1. Open **pgAdmin 4** and connect to your local server (Host: `localhost`, Port: `5432`, User: `postgres`, Password: `postgres`).
2. Right-click **Databases** -> **Create** -> **Database...**, name it **`aomf_poc`**, and click **Save**.
3. Right-click **`aomf_poc`** -> **Query Tool** (or press `Alt+Shift+Q`).
4. Open `db/init.sql` (or paste its contents) and click **Execute / Play (`F5`)** to create the `player_profile` table and seed the default `commander_fa26` row.

*(Or via terminal if `psql` is in your PATH:)*
```powershell
psql -U postgres -c "CREATE DATABASE aomf_poc;"
psql -U postgres -d aomf_poc -f db/init.sql
```

---

## How to Run the Demo

### Option A: Using `start_cloudflare.bat` (Easiest)

1. Double-click **`start_cloudflare.bat`** in the project root (or press `Ctrl+Shift+B` in VS Code).
   - This checks port `5432`, opens `pgAdmin 4`, launches the dedicated Godot Server (`Server.tscn`) on port `8080`, and starts the Cloudflare Tunnel using `cloudflare/config.yml`.
2. In the Cloudflare terminal window, copy the generated **`https://....trycloudflare.com`** URL.
3. Open `godot_poc/project.godot` in **Godot 4** and press **Play (`F5`)** to launch the Client UI (`ClientUI.tscn`).
4. Paste the `https://....trycloudflare.com` URL into the **Tunnel / Server URL** box at the top-left of the UI.

### Option B: Manual Commands (If Running Each Window Separately)

1. **Start the Dedicated Godot Server (Port 8080):**
   ```powershell
   & "path\to\Godot_console.exe" --headless --path "godot_poc" res://Server.tscn
   ```
2. **Start the Cloudflare Tunnel:**
   ```powershell
   cloudflared tunnel --config cloudflare/config.yml
   ```
3. **Run the Godot Client UI:**
   Open `godot_poc/project.godot` in Godot 4 and press **`F5`**.

---

## Monitoring & Demonstration Guide (4-Window Layout)

For a live demo on one screen, arrange these four windows side-by-side:

1. **Top-Left — Godot Client UI (`ClientUI.tscn`):**
   - Shows the current connection status (`Status: Connected to database`, or detects if `Cloudflare offline`, `Server offline`, or `Database offline`).
   - Left buttons (**Kill Enemy**, **Win Battle**, **Finish Game**, **Reset Stats**) send `POST /profile` requests through Cloudflare.
   - Right panel (**Refresh Profile**) sends `GET /profile` requests through Cloudflare to display the player's stats and unlocked achievements.
2. **Bottom-Left — Cloudflare Tunnel Terminal (`cloudflared`):**
   - Shows live `debug` logs scrolling as HTTP requests travel through Cloudflare's edge servers to `127.0.0.1:8080`.
3. **Top-Right — Dedicated Godot Server Console (`Server.tscn`):**
   - Logs incoming `Request: POST /profile` and `Request: GET /profile` calls and executes SQL against PostgreSQL.
4. **Bottom-Right — `pgAdmin 4` (`aomf_poc` Query Tool):**
   - Click on `aomf_poc` -> open **Query Tool** (`Alt+Shift+Q`) and run:
     ```sql
     SELECT * FROM player_profile;
     ```
   - Press **`F5`** in the Query Tool after clicking buttons in the Godot UI to show the database values (`enemies_killed`, `battles_won`, `games_finished`) and achievement flags (`flag_first_battle`, `flag_ten_battles`, `flag_game_finished`) updating in PostgreSQL.
