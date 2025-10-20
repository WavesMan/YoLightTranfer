/**
 * Configuration manager for application settings
 */
export class ConfigManager {
  private static instance: ConfigManager = new ConfigManager();
  private config: AppConfig;

  private constructor() {
    // Initialize with default values
    this.config = {
      deviceName: 'YoLightTransfer',
      tcpPort: 7431,
      broadcastPort: 7431,
      discoveryInterval: 5,
      chunkSize: 1024 * 1024, // 1MB
      timeout: 30,
      autoReceive: true,
      theme: 'light'
    };
  }

  public static getInstance(): ConfigManager {
    return ConfigManager.instance;
  }

  /**
   * Get current configuration
   */
  public getConfig(): AppConfig {
    return { ...this.config };
  }

  /**
   * Update configuration
   */
  public updateConfig(newConfig: Partial<AppConfig>): void {
    this.config = { ...this.config, ...newConfig };
    console.log('Configuration updated:', this.config);
    
    // TODO: Save configuration to persistent storage
    // Preferences.getPreferences().then(preferences => {
    //   preferences.put('app_config', JSON.stringify(this.config));
    //   preferences.flush();
    // });
  }

  /**
   * Load configuration from storage
   */
  public async loadConfig(): Promise<void> {
    // TODO: Load configuration from persistent storage
    // try {
    //   const preferences = await Preferences.getPreferences();
    //   const configStr = await preferences.get('app_config', '{}');
    //   const savedConfig = JSON.parse(configStr);
    //   this.config = { ...this.config, ...savedConfig };
    // } catch (error) {
    //   console.error('Failed to load configuration:', error);
    // }
  }

  /**
   * Save configuration to storage
   */
  public async saveConfig(): Promise<void> {
    // TODO: Save configuration to persistent storage
    // try {
    //   const preferences = await Preferences.getPreferences();
    //   await preferences.put('app_config', JSON.stringify(this.config));
    //   await preferences.flush();
    // } catch (error) {
    //   console.error('Failed to save configuration:', error);
    // }
  }

  /**
   * Reset configuration to defaults
   */
  public resetConfig(): void {
    this.config = {
      deviceName: 'YoLightTransfer',
      tcpPort: 7431,
      broadcastPort: 7431,
      discoveryInterval: 5,
      chunkSize: 1024 * 1024,
      timeout: 30,
      autoReceive: true,
      theme: 'light'
    };
    console.log('Configuration reset to defaults');
  }

  /**
   * Validate configuration
   */
  public validateConfig(config: AppConfig): ValidationResult {
    const errors: string[] = [];

    // Validate device name
    if (!config.deviceName || config.deviceName.trim().length === 0) {
      errors.push('设备名称不能为空');
    }

    // Validate ports
    if (config.tcpPort < 1024 || config.tcpPort > 65535) {
      errors.push('TCP端口必须在1024-65535之间');
    }

    if (config.broadcastPort < 1024 || config.broadcastPort > 65535) {
      errors.push('广播端口必须在1024-65535之间');
    }

    // Validate discovery interval
    if (config.discoveryInterval < 1 || config.discoveryInterval > 60) {
      errors.push('发现间隔必须在1-60秒之间');
    }

    // Validate chunk size
    if (config.chunkSize < 1024 || config.chunkSize > 10 * 1024 * 1024) {
      errors.push('分片大小必须在1KB-10MB之间');
    }

    // Validate timeout
    if (config.timeout < 5 || config.timeout > 300) {
      errors.push('超时时间必须在5-300秒之间');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}

/**
 * Application configuration interface
 */
export interface AppConfig {
  deviceName: string;
  tcpPort: number;
  broadcastPort: number;
  discoveryInterval: number;
  chunkSize: number;
  timeout: number;
  autoReceive: boolean;
  theme: string;
}

/**
 * Validation result interface
 */
export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

/**
 * Default configuration values
 */
export const DEFAULT_CONFIG: AppConfig = {
  deviceName: 'YoLightTransfer',
  tcpPort: 7431,
  broadcastPort: 7431,
  discoveryInterval: 5,
  chunkSize: 1024 * 1024,
  timeout: 30,
  autoReceive: true,
  theme: 'light'
};
