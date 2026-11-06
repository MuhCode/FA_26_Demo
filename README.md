# Armies of Many Fates - FA26 Demo

Prototype demo connecting a Godot 4 UI to a PostgreSQL database through a Cloudflare Tunnel.

## Project Structure

- `godot_poc/` - Godot 4 project with the client UI (`ClientUI.tscn`) and local HTTP server (`Server.gd`)
- `db/init.sql` - SQL setup for the `player_profile` table
- `start_cloudflare.bat` - Helper script to start the Cloudflare tunnel on port 8080

## How to Run

1. Run `start_cloudflare.bat` to start the tunnel pointing to `http://127.0.0.1:8080` and copy the `https://....trycloudflare.com` URL.
2. Open `godot_poc/project.godot` in Godot 4 and press Play (`F5`).
3. Paste the tunnel URL into the URL field in the UI.
4. Use the buttons on the left to update stats in PostgreSQL, and click **Refresh Profile** on the right to pull the latest stats and achievement flags from the database.
