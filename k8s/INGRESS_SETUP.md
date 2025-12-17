# Ingress Controller Setup

This project uses **NGINX Ingress Controller** to expose applications externally with a single LoadBalancer IP.

## Architecture

```
Internet → Azure LoadBalancer (Public IP) → NGINX Ingress Controller → Services → Pods
```

## Benefits

- **Single Public IP**: All applications share one LoadBalancer IP (cost-effective)
- **Path-based Routing**: Route different URLs to different services
- **SSL/TLS Termination**: Centralized certificate management
- **Better NSG Control**: Only one IP to allow in firewall rules

## Automatic Deployment

The Ingress Controller is automatically installed by the infrastructure pipeline:

1. **Infrastructure Deployment** (`aks-terraform-pipeline.yml`):
   - Deploys AKS cluster via Terraform
   - Configures NSG rules to allow LoadBalancer traffic
   - Installs NGINX Ingress Controller
   - Waits for LoadBalancer IP assignment

2. **Application Deployment** (`app-deployment.yml`):
   - Builds and pushes container images
   - Deploys backend and frontend services (ClusterIP type)
   - Creates Ingress resource to route traffic

## Access Your Application

After deployment, find the Ingress external IP:

```bash
kubectl get ingress -n book-review-dev
```

Access the application:
```
http://<INGRESS_IP>
```

## Network Security

The Terraform network module includes an NSG rule that allows external traffic:

```hcl
# modules/network/main.tf
resource "azurerm_network_security_rule" "aks_allow_loadbalancer_traffic" {
  priority               = 117
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "Tcp"
  destination_port_ranges = ["80", "443", "30000-32767"]
  source_address_prefix  = "Internet"
  destination_address_prefix = <AKS_SUBNET_CIDR>
}
```

This ensures LoadBalancer services can receive traffic from the Internet.

## Manual Installation

If you need to install the Ingress Controller manually:

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for deployment
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Get external IP
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Configuration

### Ingress Resource

Located at `k8s/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: book-review-ingress
  namespace: book-review-dev
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: book-review-frontend
            port:
              number: 80
```

### Adding More Applications

To expose additional services via the Ingress:

```yaml
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: book-review-frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: book-review-backend
            port:
              number: 8080
```

## SSL/TLS Setup (Optional)

To enable HTTPS:

1. Create a TLS secret:
```bash
kubectl create secret tls book-review-tls \
  --cert=path/to/cert.crt \
  --key=path/to/key.key \
  -n book-review-dev
```

2. Update Ingress resource:
```yaml
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: book-review-tls
  rules:
  - host: your-domain.com
    http:
      paths: ...
```

## Troubleshooting

### Ingress Controller Not Getting IP

```bash
# Check Ingress Controller pods
kubectl get pods -n ingress-nginx

# Check LoadBalancer service
kubectl get svc -n ingress-nginx

# Check events
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'
```

### Connection Timeout

```bash
# Verify NSG rules in Azure Portal
az network nsg rule list \
  --resource-group <RESOURCE_GROUP> \
  --nsg-name <NSG_NAME> \
  --query "[?direction=='Inbound'].{Name:name,Priority:priority,Access:access,DestPort:destinationPortRanges}"

# Test from within cluster
kubectl run test -it --rm --image=curlimages/curl -- \
  curl http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```

### Application Not Responding

```bash
# Check Ingress status
kubectl describe ingress book-review-ingress -n book-review-dev

# Check backend service endpoints
kubectl get endpoints -n book-review-dev

# Check Ingress Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Cost Optimization

Using Ingress Controller instead of multiple LoadBalancer services:
- **Before**: 1 public IP per service = N × $0.005/hour
- **After**: 1 public IP total = $0.005/hour
- **Savings**: ~$36/month per avoided public IP

## References

- [NGINX Ingress Controller Documentation](https://kubernetes.github.io/ingress-nginx/)
- [AKS Ingress Best Practices](https://learn.microsoft.com/en-us/azure/aks/ingress-basic)
- [Azure Load Balancer Pricing](https://azure.microsoft.com/en-us/pricing/details/load-balancer/)
