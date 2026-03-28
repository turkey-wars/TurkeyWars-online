// TurkeyWars Online — WebSocket Relay Server
// Deploy to Deno Deploy: https://dash.deno.com
//
// Protocol:
//   host → send: {"type":"host"}
//           recv: {"type":"room_created","room":"ABC123","peer_id":1}
//   join → send: {"type":"join","room":"ABC123"}
//           recv: {"type":"joined","peer_id":2,"existing_peers":[1]}
//   relay → send: {"type":"relay","target":0,"data":{...}}   (0 = broadcast)
//            recv: {"type":"relay","from":2,"data":{...}}
//   on any disconnect: {"type":"peer_disconnected","peer_id":X} sent to remaining peers

interface Room {
  peers: Map<number, WebSocket>;
  nextPeerId: number;
}

const rooms = new Map<string, Room>();

function makeCode(): string {
  // Avoids visually ambiguous characters (0/O, 1/I/L)
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

function send(ws: WebSocket, msg: object): void {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
}

Deno.serve((req: Request): Response => {
  // Health-check for browsers / uptime monitors
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response(
      JSON.stringify({ name: "TurkeyWars Relay", rooms: rooms.size }),
      { headers: { "content-type": "application/json" } },
    );
  }

  const { socket: ws, response } = Deno.upgradeWebSocket(req);
  let roomCode = "";
  let peerId = 0;

  ws.onmessage = (e: MessageEvent) => {
    let msg: Record<string, unknown>;
    try {
      msg = JSON.parse(e.data as string);
    } catch {
      return;
    }

    const type = msg["type"] as string;

    // ── Host: create a new room ─────────────────────────────────────────────
    if (type === "host") {
      let code: string;
      let tries = 0;
      do {
        code = makeCode();
        tries++;
      } while (rooms.has(code) && tries < 200);

      const room: Room = { peers: new Map([[1, ws]]), nextPeerId: 2 };
      rooms.set(code, room);
      roomCode = code;
      peerId = 1;

      send(ws, { type: "room_created", room: code, peer_id: 1 });
      return;
    }

    // ── Join: connect to existing room ──────────────────────────────────────
    if (type === "join") {
      const code = ((msg["room"] as string) ?? "").toUpperCase().trim();
      const room = rooms.get(code);

      if (!room) {
        send(ws, { type: "error", message: "Room not found. Check the code and try again." });
        return;
      }
      if (room.peers.size >= 4) {
        send(ws, { type: "error", message: "Room is full (max 4 players)." });
        return;
      }

      const newId = room.nextPeerId++;
      room.peers.set(newId, ws);
      roomCode = code;
      peerId = newId;

      send(ws, {
        type: "joined",
        peer_id: newId,
        existing_peers: Array.from(room.peers.keys()).filter((id) => id !== newId),
      });

      // Notify everyone already in the room
      for (const [pid, pws] of room.peers) {
        if (pid !== newId) send(pws, { type: "peer_connected", peer_id: newId });
      }
      return;
    }

    // ── Relay: forward a message ────────────────────────────────────────────
    if (type === "relay") {
      if (!roomCode) return;
      const room = rooms.get(roomCode);
      if (!room) return;

      const target = (msg["target"] as number) ?? 0;
      const payload = { type: "relay", from: peerId, data: msg["data"] };

      if (target === 0) {
        // Broadcast to everyone else in the room
        for (const [pid, pws] of room.peers) {
          if (pid !== peerId) send(pws, payload);
        }
      } else {
        // Unicast to a specific peer
        const pws = room.peers.get(target);
        if (pws) send(pws, payload);
      }
    }
  };

  ws.onclose = () => {
    if (!roomCode) return;
    const room = rooms.get(roomCode);
    if (!room) return;

    room.peers.delete(peerId);

    // Notify remaining peers
    for (const [, pws] of room.peers) {
      send(pws, { type: "peer_disconnected", peer_id: peerId });
    }

    // If host left or room is now empty, discard it
    if (peerId === 1 || room.peers.size === 0) {
      rooms.delete(roomCode);
    }
  };

  return response;
});
