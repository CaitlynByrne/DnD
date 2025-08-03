#!/usr/bin/env python3
"""
GameMaster's Companion Configuration Validator
Validates Helm values and Kubernetes resources for consistency and best practices
"""
import yaml
import json
import sys
import os
import argparse
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging
# Setup logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)
class ConfigValidator:
    """Validates GameMaster's Companion configuration files"""
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.project_root = Path(__file__).parent.parent.parent
        self.helm_chart_dir = self.project_root / "infrastructure" / "helm" / "gmc-dev"
    def validate_helm_values(self, values_file: Path) -> bool:
        """Validate Helm values file"""
        logger.info(f"Validating Helm values: {values_file}")
        try:
            with open(values_file, 'r') as f:
                values = yaml.safe_load(f)
        except Exception as e:
            self.errors.append(f"Failed to parse {values_file}: {e}")
            return False
        # Validate required sections
        required_sections = ['api', 'postgresql', 'redis']
        for section in required_sections:
            if section not in values:
                self.errors.append(f"Missing required section '{section}' in {values_file}")
        # Validate API configuration
        if 'api' in values:
            self._validate_api_config(values['api'])
        # Validate database configuration
        if 'postgresql' in values:
            self._validate_database_config(values['postgresql'])
        # Validate AI configuration
        if 'ai' in values:
            self._validate_ai_config(values['ai'])
        # Validate resource limits
        self._validate_resource_limits(values)
        # Validate storage configuration
        self._validate_storage_config(values)
        return len(self.errors) == 0
    def _validate_api_config(self, api_config: Dict[str, Any]):
        """Validate API service configuration"""
        # Check replica count for environment
        if api_config.get('replicaCount', 1) < 1:
            self.errors.append("API replica count must be at least 1")
        # Validate resource requests/limits
        resources = api_config.get('resources', {})
        if 'requests' in resources and 'limits' in resources:
            self._validate_resource_ratio(resources, 'api')
        # Validate health check configuration
        if 'healthCheck' in api_config and api_config['healthCheck'].get('enabled'):
            health_check = api_config['healthCheck']
            if not health_check.get('path'):
                self.warnings.append("Health check path not specified for API")
    def _validate_database_config(self, db_config: Dict[str, Any]):
        """Validate database configuration"""
        # Check persistence
        if 'primary' in db_config and 'persistence' in db_config['primary']:
            persistence = db_config['primary']['persistence']
            if persistence.get('enabled'):
                size = persistence.get('size', '')
                if not size or not self._parse_storage_size(size):
                    self.errors.append("Invalid database storage size")
        # Check authentication
        auth = db_config.get('auth', {})
        if not auth.get('database'):
            self.warnings.append("Database name not specified")
        password = auth.get('postgresPassword', '')
        if password == 'changeme':
            self.warnings.append("Default database password detected - change for production")
    def _validate_ai_config(self, ai_config: Dict[str, Any]):
        """Validate AI services configuration"""
        # Validate vLLM configuration
        if 'vllm' in ai_config and ai_config['vllm'].get('enabled'):
            vllm = ai_config['vllm']
            # Check model configuration
            model = vllm.get('model', '')
            if not model:
                self.errors.append("vLLM model not specified")
            # Check resource requirements
            resources = vllm.get('resources', {})
            if 'requests' in resources:
                memory = resources['requests'].get('memory', '')
                if memory and self._parse_memory_size(memory) < 1024:  # Less than 1GB
                    self.warnings.append("vLLM memory request may be too low for model loading")
            # Check persistence for model storage
            persistence = vllm.get('persistence', {})
            if not persistence.get('enabled'):
                self.warnings.append("vLLM persistence disabled - models will be re-downloaded on restart")
        # Validate audio processor
        if 'audioProcessor' in ai_config and ai_config['audioProcessor'].get('enabled'):
            audio = ai_config['audioProcessor']
            if not audio.get('env', {}).get('DIART_MODEL'):
                self.warnings.append("Audio processor model not specified")
    def _validate_resource_limits(self, values: Dict[str, Any]):
        """Validate resource requests and limits across all services"""
        total_cpu_requests = 0
        total_memory_requests = 0
        # Collect resource requests from all services
        services = ['api', 'frontend']
        for service in services:
            if service in values:
                resources = values[service].get('resources', {})
                if 'requests' in resources:
                    cpu = self._parse_cpu_value(resources['requests'].get('cpu', '0'))
                    memory = self._parse_memory_size(resources['requests'].get('memory', '0'))
                    total_cpu_requests += cpu
                    total_memory_requests += memory
        # Add database and cache resources
        for service in ['postgresql', 'redis']:
            if service in values:
                if service == 'postgresql' and 'primary' in values[service]:
                    resources = values[service]['primary'].get('resources', {})
                elif service == 'redis' and 'master' in values[service]:
                    resources = values[service]['master'].get('resources', {})
                else:
                    continue
                if 'requests' in resources:
                    cpu = self._parse_cpu_value(resources['requests'].get('cpu', '0'))
                    memory = self._parse_memory_size(resources['requests'].get('memory', '0'))
                    total_cpu_requests += cpu
                    total_memory_requests += memory
        # Check if total requests exceed typical development machine limits
        if total_cpu_requests > 4000:  # 4 CPU cores in millicores
            self.warnings.append(f"Total CPU requests ({total_cpu_requests}m) may exceed development machine capacity")
        if total_memory_requests > 8192:  # 8GB in MB
            self.warnings.append(f"Total memory requests ({total_memory_requests}Mi) may exceed development machine capacity")
    def _validate_storage_config(self, values: Dict[str, Any]):
        """Validate storage configuration"""
        # Check global storage class
        global_config = values.get('global', {})
        storage_class = global_config.get('storageClass', '')
        if not storage_class:
            self.warnings.append("Global storage class not specified")
        # Validate persistence configurations
        services_with_storage = ['postgresql', 'redis']
        if 'ai' in values and 'vllm' in values['ai']:
            services_with_storage.append('vllm')
        total_storage = 0
        for service in services_with_storage:
            storage_size = self._get_service_storage_size(values, service)
            if storage_size:
                total_storage += storage_size
        # Warn if total storage is very large for development
        if total_storage > 100 * 1024:  # 100GB in MB
            self.warnings.append(f"Total storage requests ({total_storage/1024:.1f}GB) are quite large for development")
    def _get_service_storage_size(self, values: Dict[str, Any], service: str) -> int:
        """Get storage size for a service in MB"""
        if service == 'postgresql':
            persistence = values.get('postgresql', {}).get('primary', {}).get('persistence', {})
        elif service == 'redis':
            persistence = values.get('redis', {}).get('master', {}).get('persistence', {})
        elif service == 'vllm':
            persistence = values.get('ai', {}).get('vllm', {}).get('persistence', {})
        else:
            return 0
        if persistence.get('enabled'):
            size = persistence.get('size', '')
            return self._parse_storage_size(size) or 0
        return 0
    def _validate_resource_ratio(self, resources: Dict[str, Any], service: str):
        """Validate that limits are reasonable compared to requests"""
        requests = resources.get('requests', {})
        limits = resources.get('limits', {})
        # Check CPU ratio
        if 'cpu' in requests and 'cpu' in limits:
            req_cpu = self._parse_cpu_value(requests['cpu'])
            lim_cpu = self._parse_cpu_value(limits['cpu'])
            if lim_cpu < req_cpu:
                self.errors.append(f"{service}: CPU limit ({limits['cpu']}) is less than request ({requests['cpu']})")
            elif lim_cpu > req_cpu * 4:  # More than 4x request
                self.warnings.append(f"{service}: CPU limit is much higher than request - consider adjusting")
        # Check memory ratio
        if 'memory' in requests and 'memory' in limits:
            req_mem = self._parse_memory_size(requests['memory'])
            lim_mem = self._parse_memory_size(limits['memory'])
            if lim_mem < req_mem:
                self.errors.append(f"{service}: Memory limit ({limits['memory']}) is less than request ({requests['memory']})")
            elif lim_mem > req_mem * 4:  # More than 4x request
                self.warnings.append(f"{service}: Memory limit is much higher than request - consider adjusting")
    def _parse_cpu_value(self, cpu_str: str) -> int:
        """Parse CPU value to millicores"""
        if not cpu_str:
            return 0
        cpu_str = str(cpu_str).lower()
        if cpu_str.endswith('m'):
            return int(cpu_str[:-1])
        else:
            return int(float(cpu_str) * 1000)
    def _parse_memory_size(self, memory_str: str) -> int:
        """Parse memory size to MB"""
        if not memory_str:
            return 0
        memory_str = str(memory_str).upper()
        if memory_str.endswith('MI'):
            return int(memory_str[:-2])
        elif memory_str.endswith('GI'):
            return int(memory_str[:-2]) * 1024
        elif memory_str.endswith('M'):
            return int(memory_str[:-1])
        elif memory_str.endswith('G'):
            return int(memory_str[:-1]) * 1024
        else:
            return int(memory_str)
    def _parse_storage_size(self, storage_str: str) -> Optional[int]:
        """Parse storage size to MB"""
        if not storage_str:
            return None
        storage_str = str(storage_str).upper()
        if storage_str.endswith('GI'):
            return int(storage_str[:-2]) * 1024
        elif storage_str.endswith('G'):
            return int(storage_str[:-1]) * 1024
        elif storage_str.endswith('MI'):
            return int(storage_str[:-2])
        elif storage_str.endswith('M'):
            return int(storage_str[:-1])
        else:
            try:
                return int(storage_str)
            except ValueError:
                return None
    def validate_chart_structure(self) -> bool:
        """Validate Helm chart structure"""
        logger.info("Validating Helm chart structure")
        # Check required files
        required_files = [
            'Chart.yaml',
            'values.yaml',
            'values-development.yaml',
            'values-production.yaml'
        ]
        for file_name in required_files:
            file_path = self.helm_chart_dir / file_name
            if not file_path.exists():
                self.errors.append(f"Missing required file: {file_path}")
        # Check templates directory
        templates_dir = self.helm_chart_dir / 'templates'
        if not templates_dir.exists():
            self.errors.append("Missing templates directory")
        else:
            # Check for basic template files
            template_files = ['deployment.yaml', 'service.yaml', 'configmap.yaml']
            for template in template_files:
                template_path = templates_dir / template
                if not template_path.exists():
                    self.warnings.append(f"Missing template file: {template}")
        return len(self.errors) == 0
    def validate_kind_config(self) -> bool:
        """Validate Kind cluster configuration"""
        logger.info("Validating Kind cluster configuration")
        kind_config_path = self.project_root / "infrastructure" / "kind-cluster-config.yaml"
        if not kind_config_path.exists():
            self.errors.append("Missing Kind cluster configuration file")
            return False
        try:
            with open(kind_config_path, 'r') as f:
                config = yaml.safe_load(f)
        except Exception as e:
            self.errors.append(f"Failed to parse Kind config: {e}")
            return False
        # Validate cluster configuration
        if config.get('kind') != 'Cluster':
            self.errors.append("Kind config must be of type 'Cluster'")
        # Check nodes configuration
        nodes = config.get('nodes', [])
        if not nodes:
            self.errors.append("At least one node must be defined")
        # Check for control plane
        control_plane_nodes = [n for n in nodes if n.get('role') == 'control-plane']
        if not control_plane_nodes:
            self.errors.append("At least one control-plane node must be defined")
        # Validate port mappings
        for node in nodes:
            if node.get('role') == 'control-plane':
                port_mappings = node.get('extraPortMappings', [])
                if not port_mappings:
                    self.warnings.append("No port mappings defined for control plane - services won't be accessible")
        return len(self.errors) == 0
    def generate_report(self) -> str:
        """Generate validation report"""
        report = ["=" * 60]
        report.append("GameMaster's Companion Configuration Validation Report")
        report.append("=" * 60)
        if self.errors:
            report.append(f"\n❌ ERRORS ({len(self.errors)}):")
            for error in self.errors:
                report.append(f"  • {error}")
        if self.warnings:
            report.append(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                report.append(f"  • {warning}")
        if not self.errors and not self.warnings:
            report.append("\n✅ All validations passed!")
        report.append("\n" + "=" * 60)
        return "\n".join(report)
def main():
    parser = argparse.ArgumentParser(description="Validate GameMaster's Companion configuration")
    parser.add_argument('--values-file', type=Path, help="Specific values file to validate")
    parser.add_argument('--environment', choices=['development', 'production'], 
                       help="Validate specific environment configuration")
    parser.add_argument('--strict', action='store_true', 
                       help="Treat warnings as errors")
    args = parser.parse_args()
    validator = ConfigValidator()
    # Validate chart structure
    validator.validate_chart_structure()
    # Validate Kind configuration
    validator.validate_kind_config()
    # Validate values files
    if args.values_file:
        validator.validate_helm_values(args.values_file)
    elif args.environment:
        values_file = validator.helm_chart_dir / f"values-{args.environment}.yaml"
        validator.validate_helm_values(values_file)
        # Also validate base values
        base_values = validator.helm_chart_dir / "values.yaml"
        validator.validate_helm_values(base_values)
    else:
        # Validate all values files
        for values_file in validator.helm_chart_dir.glob("values*.yaml"):
            validator.validate_helm_values(values_file)
    # Generate and print report
    report = validator.generate_report()
    print(report)
    # Exit with appropriate code
    has_errors = len(validator.errors) > 0
    has_warnings = len(validator.warnings) > 0
    if has_errors or (args.strict and has_warnings):
        sys.exit(1)
    else:
        sys.exit(0)
if __name__ == "__main__":
    main()