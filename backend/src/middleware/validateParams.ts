import { Request, Response, NextFunction } from 'express';

// Helper to strictly test positive integers safely across Express parameter types
const isPositiveInteger = (val: string | string[] | undefined): boolean => {
  if (!val) return false;
  const strVal = Array.isArray(val) ? val[0] : val;
  if (typeof strVal !== 'string' || strVal.trim() === '') return false;

  const num = Number(strVal);
  return Number.isInteger(num) && num > 0;
};

/**
 * Factory middleware to validate numeric IDs in req.params
 * @param paramNames Array of parameter names to validate (e.g. ['chatId', 'userId'])
 */
export const validateNumericParams = (...paramNames: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    for (const paramName of paramNames) {
      const value = req.params[paramName];

      if (value !== undefined && !isPositiveInteger(value)) {
        return res.status(400).json({
          error: `Invalid ${paramName}: must be a positive integer`,
        });
      }
    }

    next();
  };
};