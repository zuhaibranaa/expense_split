from typing import Dict, List
import json
from fastapi import WebSocket
from app.models.member import Member

class ConnectionManager:
    def __init__(self):
        # active_connections: user_id -> List[WebSocket]
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, websocket: WebSocket, user_id: int):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_personal_message(self, message: str, user_id: int):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_text(message)
                except:
                    pass # Connection might be closed

    async def broadcast_to_group(self, group_id: int, message: dict, members: List[Member]):
        json_message = json.dumps(message)
        for member in members:
            if member.user_id and member.user_id in self.active_connections:
                for connection in self.active_connections[member.user_id]:
                    try:
                        await connection.send_text(json_message)
                    except:
                        pass

manager = ConnectionManager()
