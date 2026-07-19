{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    kubectl
    kubectl-neat
    kubectl-node-shell
    kubectl-cnpg
    kubectx
    stern
    pinniped
    kubernetes-helm
    argocd
  ];

  programs.bash = {
    shellAliases = {
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
      kdp = "kubectl describe pod";
      kdn = "kubectl describe node";
      kd = "kubectl describe";
      ko = ''kubectl get pods -A -o wide | egrep -vi "running|completed"'';
      wkow = ''watch "kubectl get pods -A -o wide | egrep -vi \"running|completed\""'';
      wko = ''watch "kubectl get pods -A | egrep -vi \"running|completed\""'';
      ksp = "kubectl get pods -A -o wide | grep";
      kgp = "kubectl get pods -o wide | grep";
      kgd = "kubectl get deploy -o wide | grep";
    };

    bashrcExtra = ''
      # FZF-based kubectl exec into a running pod
      kex() {
        local pod
        pod=$(k get pods | grep -v NAME | grep Running | fzf | awk '{print $1}')
        [[ -n "$pod" ]] && kubectl exec -it "$pod" -- "''${1:-bash}"
      }

      # Diff two Kubernetes resources using kubectl-neat + delta
      kdiff() {
        if [[ "$#" -ne 2 ]]; then
          echo "Usage: kdiff <resource1> <resource2>"
          return 1
        fi
        local resource1=$1 resource2=$2
        local tmpfile1 tmpfile2
        tmpfile1=$(mktemp /tmp/resource1.XXXXXX.yaml)
        tmpfile2=$(mktemp /tmp/resource2.XXXXXX.yaml)
        if ! kubectl get "$resource1" -o yaml | kubectl neat > "$tmpfile1"; then
          echo "Failed to get resource: $resource1"
          rm -f "$tmpfile1" "$tmpfile2"
          return 1
        fi
        if ! kubectl get "$resource2" -o yaml | kubectl neat > "$tmpfile2"; then
          echo "Failed to get resource: $resource2"
          rm -f "$tmpfile1" "$tmpfile2"
          return 1
        fi
        delta "$tmpfile1" "$tmpfile2" && echo "No differences found." || echo "Differences found."
        rm -f "$tmpfile1" "$tmpfile2"
      }

      # Decode base64 Kubernetes secret values
      ksecret() {
        local secret_name=$1 namespace=$2
        if [[ -z "$namespace" ]]; then
          namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
        fi
        kubectl get secret "$secret_name" -n "$namespace" -o json | \
          jq -r '.data | to_entries[] | "\(.key) = \(.value | @base64d)"'
      }
    '';
  };
}
