export interface TallyOptions {
  apiKey: string;
  endpoint: string;
  batchSize?: number;
  flushInterval?: number;
  timeout?: number;
}

export interface TrackOptions {
  timestamp?: string;
  idempotencyKey?: string;
}

export class TallyAnalytics {
  constructor(options: TallyOptions);
  track(userId: string, eventName: string, properties?: Record<string, unknown>, options?: TrackOptions): void;
  identify(userId: string, properties?: Record<string, unknown>): Promise<void>;
  alias(anonymousId: string, userId: string): Promise<void>;
  flush(): Promise<void>;
  shutdown(): Promise<void>;
}
