"""
Logging Configuration for Mineral Traceability System
Tracks scan events, modality presence, confidence scores, and errors
"""

import logging
import json
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional


class ScanEventLogger:
    """
    Structured logger for scan events
    """
    def __init__(self, log_dir: Path):
        self.log_dir = log_dir
        self.log_dir.mkdir(parents=True, exist_ok=True)
        
        # Configure loggers
        self.setup_loggers()
    
    def setup_loggers(self):
        """Setup different loggers for different purposes"""
        
        # Main application logger
        self.app_logger = logging.getLogger('app')
        self.app_logger.setLevel(logging.INFO)
        app_handler = logging.FileHandler(self.log_dir / 'app.log')
        app_handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        ))
        self.app_logger.addHandler(app_handler)
        
        # Scan events logger (structured JSON)
        self.scan_logger = logging.getLogger('scans')
        self.scan_logger.setLevel(logging.INFO)
        scan_handler = logging.FileHandler(self.log_dir / 'scans.jsonl')
        scan_handler.setFormatter(logging.Formatter('%(message)s'))
        self.scan_logger.addHandler(scan_handler)
        
        # Model predictions logger
        self.model_logger = logging.getLogger('model')
        self.model_logger.setLevel(logging.INFO)
        model_handler = logging.FileHandler(self.log_dir / 'model_predictions.jsonl')
        model_handler.setFormatter(logging.Formatter('%(message)s'))
        self.model_logger.addHandler(model_handler)
        
        # Error logger
        self.error_logger = logging.getLogger('errors')
        self.error_logger.setLevel(logging.ERROR)
        error_handler = logging.FileHandler(self.log_dir / 'errors.log')
        error_handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s\n%(exc_info)s'
        ))
        self.error_logger.addHandler(error_handler)
    
    def log_scan_event(self, 
                      sample_id: str,
                      user_id: str,
                      modalities_used: Dict[str, bool],
                      predicted_mineral: str,
                      claimed_mineral: str,
                      confidence: float,
                      status: str,
                      site: str):
        """Log a scan event in structured format"""
        event = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': 'scan',
            'sample_id': sample_id,
            'user_id': user_id,
            'site': site,
            'modalities': modalities_used,
            'modality_count': sum(modalities_used.values()),
            'claimed_mineral': claimed_mineral,
            'predicted_mineral': predicted_mineral,
            'confidence': confidence,
            'status': status,
            'match': predicted_mineral.lower() == claimed_mineral.lower()
        }
        
        self.scan_logger.info(json.dumps(event))
        self.app_logger.info(
            f"Scan {sample_id}: {claimed_mineral} -> {predicted_mineral} "
            f"({confidence:.2%}) - Status: {status}"
        )
    
    def log_model_prediction(self,
                            predicted_mineral: str = None,
                            prediction: str = None,
                            confidence: float = 0.0,
                            modalities: Dict[str, bool] = None,
                            modalities_present: Dict[str, bool] = None,
                            sample_id: str = None,
                            all_scores: Optional[Dict[str, float]] = None):
        """Log model prediction details - flexible parameter names"""
        # Support both parameter naming conventions
        actual_prediction = prediction or predicted_mineral or "unknown"
        actual_modalities = modalities_present or modalities or {}
        
        pred_event = {
            'timestamp': datetime.utcnow().isoformat(),
            'sample_id': sample_id or 'unknown',
            'modalities': actual_modalities,
            'prediction': actual_prediction,
            'confidence': confidence,
            'scores': all_scores or {}
        }
        
        self.model_logger.info(json.dumps(pred_event))
    
    def log_error(self, 
                 error_or_type,
                 message_or_context = None,
                 context: Optional[Dict[str, Any]] = None,
                 exception: Optional[Exception] = None):
        """Log errors with context - flexible parameter handling"""
        # Support two call patterns:
        # 1. log_error(exception, context_dict) - new style
        # 2. log_error(error_type, message, context, exception) - old style
        
        if isinstance(error_or_type, Exception):
            # New style: log_error(exception, context_dict)
            actual_exception = error_or_type
            actual_context = message_or_context if isinstance(message_or_context, dict) else {}
            error_msg = f"Exception: {str(actual_exception)}"
            if actual_context:
                error_msg += f" | Context: {json.dumps(actual_context)}"
            self.error_logger.error(error_msg, exc_info=actual_exception)
        else:
            # Old style: log_error(error_type, message, context, exception)
            error_type = error_or_type
            message = message_or_context or ""
            error_msg = f"{error_type}: {message}"
            if context:
                error_msg += f" | Context: {json.dumps(context)}"
            
            if exception:
                self.error_logger.error(error_msg, exc_info=exception)
            else:
                self.error_logger.error(error_msg)
    
    def log_modality_missing(self,
                            sample_id: str,
                            missing_modalities: list):
        """Log when modalities are missing"""
        self.app_logger.warning(
            f"Sample {sample_id}: Missing modalities {missing_modalities}"
        )


def get_scan_statistics(log_file: Path) -> Dict[str, Any]:
    """
    Analyze scan logs to get statistics
    """
    if not log_file.exists():
        return {}
    
    scans = []
    with open(log_file, 'r') as f:
        for line in f:
            try:
                scans.append(json.loads(line))
            except:
                continue
    
    if not scans:
        return {}
    
    total = len(scans)
    
    # Count by modality combinations
    modality_combos = {}
    for scan in scans:
        mods = scan.get('modalities', {})
        key = '+'.join([k for k, v in mods.items() if v])
        modality_combos[key] = modality_combos.get(key, 0) + 1
    
    # Count by status
    statuses = {}
    for scan in scans:
        status = scan.get('status', 'unknown')
        statuses[status] = statuses.get(status, 0) + 1
    
    # Average confidence
    confidences = [s.get('confidence', 0) for s in scans]
    avg_confidence = sum(confidences) / len(confidences) if confidences else 0
    
    # Match rate
    matches = sum(1 for s in scans if s.get('match', False))
    match_rate = matches / total if total > 0 else 0
    
    return {
        'total_scans': total,
        'modality_combinations': modality_combos,
        'status_distribution': statuses,
        'average_confidence': avg_confidence,
        'match_rate': match_rate,
        'verification_rate': statuses.get('verified', 0) / total if total > 0 else 0
    }
