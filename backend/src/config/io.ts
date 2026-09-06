import { Server } from "socket.io";

/**
 * Singleton IO instance shared across modules.
 * Set once during server startup, then accessed by controllers/services
 * that need to push real-time events (e.g. session revocation).
 */
let _io: Server | null = null;

export function setIo(io: Server): void {
  _io = io;
}

export function getIo(): Server {
  if (!_io) {
    throw new Error("Socket.IO server not initialized yet. Call setIo() first.");
  }
  return _io;
}
