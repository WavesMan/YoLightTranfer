"""
Data Preprocessor for Network Quality Analysis

This module handles data preprocessing, feature engineering, and data cleaning
for network quality data before model training.
"""

import pandas as pd
import numpy as np
from typing import Tuple, Dict, List
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.model_selection import train_test_split
import warnings


class DataPreprocessor:
    """
    Preprocesses network quality data for AI model training.
    
    This class handles:
    - Data cleaning and outlier removal
    - Feature scaling and normalization
    - Feature engineering
    - Train-test splitting
    - Data validation
    """
    
    def __init__(self):
        """Initialize preprocessor with default parameters."""
        self.scaler = StandardScaler()
        self.feature_columns = ["bandwidthMbps", "avgDelayMs", "packetLossRate"]
        self.label_columns = ["shouldRecommendHotspot", "qualityScore", "confidence"]
        self.is_fitted = False
    
    def preprocess_data(self, df: pd.DataFrame, 
                       test_size: float = 0.2, 
                       validation_size: float = 0.1,
                       random_state: int = 42) -> Tuple:
        """
        Preprocess the complete dataset for training.
        
        Args:
            df: Input DataFrame with network data
            test_size: Proportion of data for testing
            validation_size: Proportion of training data for validation
            random_state: Random seed for reproducibility
            
        Returns:
            Tuple of (X_train, X_val, X_test, y_train, y_val, y_test, feature_scaler)
        """
        # Validate input data
        self._validate_data(df)
        
        # Clean data
        df_clean = self._clean_data(df)
        
        # Extract features and labels
        X = df_clean[self.feature_columns].values
        y = df_clean[self.label_columns].values
        
        # Split data
        X_temp, X_test, y_temp, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state, stratify=y[:, 0]
        )
        
        # Further split temp data into train and validation
        val_size_adjusted = validation_size / (1 - test_size)
        X_train, X_val, y_train, y_val = train_test_split(
            X_temp, y_temp, test_size=val_size_adjusted, 
            random_state=random_state, stratify=y_temp[:, 0]
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_val_scaled = self.scaler.transform(X_val)
        X_test_scaled = self.scaler.transform(X_test)
        
        self.is_fitted = True
        
        return (X_train_scaled, X_val_scaled, X_test_scaled, 
                y_train, y_val, y_test, self.scaler)
    
    def _validate_data(self, df: pd.DataFrame):
        """Validate input data structure and quality."""
        required_columns = self.feature_columns + self.label_columns
        
        # Check for required columns
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise ValueError(f"Missing required columns: {missing_columns}")
        
        # Check for NaN values
        if df[required_columns].isna().any().any():
            warnings.warn("Dataset contains NaN values. They will be handled during cleaning.")
        
        # Check data types
        for col in self.feature_columns:
            if not pd.api.types.is_numeric_dtype(df[col]):
                raise ValueError(f"Column {col} must be numeric")
    
    def _clean_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Clean and prepare data for processing."""
        df_clean = df.copy()
        
        # Handle NaN values
        df_clean[self.feature_columns] = df_clean[self.feature_columns].fillna(
            df_clean[self.feature_columns].median()
        )
        
        # Remove outliers using IQR method
        for col in self.feature_columns:
            Q1 = df_clean[col].quantile(0.25)
            Q3 = df_clean[col].quantile(0.75)
            IQR = Q3 - Q1
            lower_bound = Q1 - 1.5 * IQR
            upper_bound = Q3 + 1.5 * IQR
            
            # Cap outliers instead of removing them
            df_clean[col] = df_clean[col].clip(lower=lower_bound, upper=upper_bound)
        
        # Ensure labels are within valid ranges
        df_clean["shouldRecommendHotspot"] = df_clean["shouldRecommendHotspot"].clip(0, 1)
        df_clean["qualityScore"] = df_clean["qualityScore"].clip(0.0, 1.0)
        df_clean["confidence"] = df_clean["confidence"].clip(0.0, 1.0)
        
        return df_clean
    
    def engineer_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Create additional engineered features from raw network data.
        
        Args:
            df: Input DataFrame with basic network features
            
        Returns:
            DataFrame with additional engineered features
        """
        df_engineered = df.copy()
        
        # Network quality composite score
        df_engineered["network_quality_index"] = (
            df_engineered["bandwidthMbps"] / 100.0 * 0.5 +
            (1 - df_engineered["avgDelayMs"] / 500.0) * 0.3 +
            (1 - df_engineered["packetLossRate"] / 20.0) * 0.2
        )
        
        # Bandwidth-to-delay ratio (higher is better)
        df_engineered["bandwidth_delay_ratio"] = (
            df_engineered["bandwidthMbps"] / (df_engineered["avgDelayMs"] + 1)
        )
        
        # Network stability indicator (lower loss and delay variation)
        df_engineered["stability_score"] = (
            1.0 - (df_engineered["packetLossRate"] * df_engineered["avgDelayMs"]) / 10000.0
        )
        
        # Categorical features based on network conditions
        df_engineered["network_category"] = pd.cut(
            df_engineered["bandwidthMbps"],
            bins=[0, 10, 30, 100],
            labels=["weak", "medium", "strong"]
        )
        
        # Delay category
        df_engineered["delay_category"] = pd.cut(
            df_engineered["avgDelayMs"],
            bins=[0, 50, 150, 500],
            labels=["low", "medium", "high"]
        )
        
        return df_engineered
    
    def transform_new_data(self, X: np.ndarray) -> np.ndarray:
        """
        Transform new data using fitted scaler.
        
        Args:
            X: New feature data to transform
            
        Returns:
            Scaled feature data
        """
        if not self.is_fitted:
            raise ValueError("Preprocessor must be fitted before transforming new data")
        
        return self.scaler.transform(X)
    
    def get_feature_importance_analysis(self, df: pd.DataFrame) -> Dict:
        """
        Analyze feature importance and correlations.
        
        Args:
            df: Input DataFrame with features and labels
            
        Returns:
            Dictionary with feature analysis results
        """
        analysis = {}
        
        # Correlation with hotspot recommendation
        correlations = df[self.feature_columns].corrwith(df["shouldRecommendHotspot"])
        analysis["correlation_with_hotspot"] = correlations.to_dict()
        
        # Feature statistics
        for col in self.feature_columns:
            analysis[f"{col}_stats"] = {
                "mean": df[col].mean(),
                "std": df[col].std(),
                "min": df[col].min(),
                "max": df[col].max(),
                "median": df[col].median()
            }
        
        # Class distribution
        analysis["class_distribution"] = df["shouldRecommendHotspot"].value_counts().to_dict()
        
        return analysis
    
    def save_preprocessor(self, filepath: str):
        """Save fitted preprocessor to file."""
        import joblib
        
        if not self.is_fitted:
            raise ValueError("Preprocessor must be fitted before saving")
        
        joblib.dump({
            'scaler': self.scaler,
            'feature_columns': self.feature_columns,
            'label_columns': self.label_columns,
            'is_fitted': self.is_fitted
        }, filepath)
    
    def load_preprocessor(self, filepath: str):
        """Load preprocessor from file."""
        import joblib
        
        preprocessor_data = joblib.load(filepath)
        self.scaler = preprocessor_data['scaler']
        self.feature_columns = preprocessor_data['feature_columns']
        self.label_columns = preprocessor_data['label_columns']
        self.is_fitted = preprocessor_data['is_fitted']


# Example usage
if __name__ == "__main__":
    # Create sample data for testing
    from generator import DataGenerator
    
    generator = DataGenerator()
    sample_df = generator.generate_dataset(n_samples=100)
    
    # Test preprocessor
    preprocessor = DataPreprocessor()
    
    # Preprocess data
    X_train, X_val, X_test, y_train, y_val, y_test, scaler = preprocessor.preprocess_data(sample_df)
    
    print("Preprocessing completed successfully!")
    print(f"Training set: {X_train.shape}")
    print(f"Validation set: {X_val.shape}")
    print(f"Test set: {X_test.shape}")
    
    # Feature engineering
    engineered_df = preprocessor.engineer_features(sample_df)
    print(f"\nEngineered features: {engineed_df.shape}")
    print("New columns:", [col for col in engineered_df.columns if col not in sample_df.columns])
    
    # Feature analysis
    analysis = preprocessor.get_feature_importance_analysis(sample_df)
    print(f"\nFeature analysis: {analysis.keys()}")
