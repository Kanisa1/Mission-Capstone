"""
Model Evaluation Metrics Calculator
Computes accuracy, precision, recall, F1, and FPR from verification records
"""

from typing import Dict, List, Tuple
import json
from pathlib import Path
from collections import defaultdict


class MetricsCalculator:
    """
    Calculate classification metrics from verification records
    """
    def __init__(self, fingerprints_file: Path):
        self.fingerprints_file = Path(fingerprints_file) if not isinstance(fingerprints_file, Path) else fingerprints_file
        self.mineral_labels = ["gold", "chalcopyrite", "hematite"]
    
    def load_records(self) -> List[Dict]:
        """Load all verification records"""
        if not self.fingerprints_file.exists():
            return []
        
        records = []
        with open(self.fingerprints_file, 'r') as f:
            for line in f:
                try:
                    records.append(json.loads(line))
                except:
                    continue
        return records
    
    def calculate_metrics(self) -> Dict:
        """
        Calculate comprehensive metrics
        Returns accuracy, precision, recall, F1, FPR per class and overall
        """
        records = self.load_records()
        
        # Filter records that have both predicted and claimed mineral
        valid_records = [
            r for r in records 
            if r.get('predicted_mineral') and r.get('mineral') and r.get('confidence') is not None
        ]
        
        if not valid_records:
            return {
                'status': 'no_data',
                'message': 'No records with predictions available',
                'total_records': len(records)
            }
        
        # Initialize confusion matrix
        confusion = defaultdict(lambda: defaultdict(int))
        
        # Count predictions
        for record in valid_records:
            true_label = record['mineral'].lower()
            pred_label = record['predicted_mineral'].lower()
            confusion[true_label][pred_label] += 1
        
        # Calculate per-class metrics
        per_class_metrics = {}
        
        for mineral in self.mineral_labels:
            tp = confusion[mineral][mineral]
            fp = sum(confusion[other][mineral] for other in self.mineral_labels if other != mineral)
            fn = sum(confusion[mineral][other] for other in self.mineral_labels if other != mineral)
            tn = sum(
                confusion[t][p] 
                for t in self.mineral_labels 
                for p in self.mineral_labels 
                if t != mineral and p != mineral
            )
            
            # Precision
            precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
            
            # Recall (Sensitivity)
            recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
            
            # F1 Score
            f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0
            
            # False Positive Rate
            fpr = fp / (fp + tn) if (fp + tn) > 0 else 0.0
            
            # Specificity
            specificity = tn / (tn + fp) if (tn + fp) > 0 else 0.0
            
            per_class_metrics[mineral] = {
                'true_positives': tp,
                'false_positives': fp,
                'false_negatives': fn,
                'true_negatives': tn,
                'precision': round(precision, 4),
                'recall': round(recall, 4),
                'f1_score': round(f1, 4),
                'fpr': round(fpr, 4),
                'specificity': round(specificity, 4)
            }
        
        # Overall accuracy
        total_correct = sum(confusion[m][m] for m in self.mineral_labels)
        total_samples = len(valid_records)
        accuracy = total_correct / total_samples if total_samples > 0 else 0.0
        
        # Macro-averaged metrics
        macro_precision = sum(m['precision'] for m in per_class_metrics.values()) / len(self.mineral_labels)
        macro_recall = sum(m['recall'] for m in per_class_metrics.values()) / len(self.mineral_labels)
        macro_f1 = sum(m['f1_score'] for m in per_class_metrics.values()) / len(self.mineral_labels)
        macro_fpr = sum(m['fpr'] for m in per_class_metrics.values()) / len(self.mineral_labels)
        
        # Confidence distribution
        confidences = [r['confidence'] for r in valid_records]
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0
        
        # Modality usage statistics
        modality_stats = self._calculate_modality_stats(valid_records)
        
        return {
            'status': 'success',
            'total_samples': total_samples,
            'total_records': len(records),
            'overall_metrics': {
                'accuracy': round(accuracy, 4),
                'macro_precision': round(macro_precision, 4),
                'macro_recall': round(macro_recall, 4),
                'macro_f1_score': round(macro_f1, 4),
                'macro_fpr': round(macro_fpr, 4),
                'avg_confidence': round(avg_confidence, 4)
            },
            'per_class_metrics': per_class_metrics,
            'confusion_matrix': {
                true_label: dict(pred_dict) 
                for true_label, pred_dict in confusion.items()
            },
            'modality_statistics': modality_stats
        }
    
    def _calculate_modality_stats(self, records: List[Dict]) -> Dict:
        """Calculate statistics about modality usage"""
        modality_combos = defaultdict(int)
        total_with_modality_info = 0
        
        for record in records:
            # Check if record has modality information
            if 'modalities_used' in record:
                total_with_modality_info += 1
                mods = record['modalities_used']
                combo = '+'.join(sorted([k for k, v in mods.items() if v]))
                modality_combos[combo] += 1
        
        return {
            'total_with_modality_info': total_with_modality_info,
            'modality_combinations': dict(modality_combos)
        }
    
    def get_verification_stats(self) -> Dict:
        """Get statistics about verification statuses"""
        records = self.load_records()
        
        status_counts = defaultdict(int)
        confidence_by_status = defaultdict(list)
        
        for record in records:
            # Calculate status based on prediction
            predicted = record.get('predicted_mineral', '').lower()
            claimed = record.get('mineral', '').lower()
            confidence = record.get('confidence')
            
            if predicted and claimed and confidence is not None:
                if predicted == claimed and confidence >= 0.80:
                    status = 'verified'
                elif confidence < 0.60:
                    status = 'pending'
                else:
                    status = 'notVerified'
                
                status_counts[status] += 1
                confidence_by_status[status].append(confidence)
        
        # Calculate average confidence per status
        avg_confidence_by_status = {
            status: sum(confs) / len(confs) if confs else 0.0
            for status, confs in confidence_by_status.items()
        }
        
        return {
            'status_counts': dict(status_counts),
            'avg_confidence_by_status': {
                k: round(v, 4) for k, v in avg_confidence_by_status.items()
            },
            'total_verifications': sum(status_counts.values())
        }
