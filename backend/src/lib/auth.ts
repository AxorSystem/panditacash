import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import type { Request, Response, NextFunction } from 'express';

export interface UserPayload {
  id: number;
  telefono: string;
  nombre: string;
  es_admin: boolean;
}

export function signToken(user: UserPayload): string {
  return jwt.sign(user, config.jwtSecret, { expiresIn: '30d' });
}

export function verifyToken(token: string): UserPayload | null {
  try {
    return jwt.verify(token, config.jwtSecret) as UserPayload;
  } catch {
    return null;
  }
}

export function requireAuth(req: any, res: Response, next: NextFunction) {
  const auth = req.headers.authorization?.replace('Bearer ', '') ?? '';
  const payload = verifyToken(auth);
  if (!payload) return res.status(401).json({ error: 'No autenticado' });
  req.user = payload;
  next();
}

export function requireAdmin(req: any, res: Response, next: NextFunction) {
  if (!req.user?.es_admin) return res.status(403).json({ error: 'Solo mamá tiene acceso a esto' });
  next();
}
