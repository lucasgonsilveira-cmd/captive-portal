# Portal cativo "Eng-Software" — guia rápido

Cria a rede Wi-Fi aberta **Eng-Software** no notebook (Linux Mint). Quem conecta vê o portal da Fatec Jahu
e só ganha internet ao clicar em **Liberar acesso**. **Só 10 aparelhos** conseguem internet de verdade;
os outros ainda abrem o portal.

```
 4G do celular ──Wi-Fi──▶ notebook ──Wi-Fi aberta "Eng-Software"──▶ celulares da plateia
```

## Dia da apresentação (3 passos)

1. **No celular:** ligue o hotspot e deixe a banda em **2,4 GHz** (Config. > Hotspot > Banda do ponto de acesso).
2. **No notebook:** conecte no Wi-Fi do celular e abra o terminal na pasta do projeto:
   ```bash
   bash iniciar.sh
   ```
   (pede a senha do notebook; na primeira vez instala o que falta, então precisa de internet)
3. Espere aparecer o quadro verde **REDE PRONTA**. Pronto: os celulares já veem a rede **Eng-Software**.

Para encerrar: **Ctrl+C** no terminal. O notebook volta ao normal sozinho.

### O que a plateia faz
Conecta em *Eng-Software* → o portal abre sozinho (Android/iPhone: aviso "fazer login na rede").
Se não abrir, é só digitar `http://10.77.0.1` no navegador → botão **Liberar acesso**.
(Os links para o site oficial da Fatec só abrem depois de liberar o acesso.)

### Painel do apresentador
No navegador **do notebook**: `http://10.77.0.1/admin`. Mostra quantos estão liberados (x/10), permite
**remover** um aparelho (libera a vaga) ou **zerar todos**. O terminal também mostra cada liberação.

## Antes da apresentação: ensaie!
1. Em casa, **com internet**, uma vez só: `bash iniciar.sh preparar` (instala o que falta).
   O Bootstrap já vem dentro do projeto, então o portal abre mesmo sem internet.
2. Veja o site sem mexer na rede: `bash iniciar.sh teste` → abra `http://localhost:8080`.
3. Faça o ensaio completo (`bash iniciar.sh`) com 1 ou 2 celulares **antes do dia**.

## Plano B — celular por cabo USB (alternativa)
Se o Wi-Fi do celular + a rede Eng-Software na mesma placa não funcionar:
1. Conecte o celular por **cabo USB** (use um cabo que transfira dados; alguns só carregam) e ative **Compartilhar internet por USB**.
2. Confira que apareceu uma conexão cabeada nova no ícone de rede do notebook.
3. **Desconecte** o notebook do Wi-Fi do celular.
4. Rode `bash iniciar.sh` de novo. O script percebe sozinho e usa a placa Wi-Fi só para a rede Eng-Software.

Na faculdade você também pode usar o cabo de rede (Ethernet) como internet: o script trata igual ao USB.

## Onde mudar as coisas
| O quê | Onde |
|---|---|
| Nome da rede, limite de aparelhos, faixa de IP | `config.env` |
| Avisos exibidos no portal | `dados/avisos.json` |
| Alunos da "Área do aluno" (RA de exemplo: `1234567890123`) | `dados/alunos.json` |
| E-mails cadastrados pelo portal | `dados/inscricoes.csv` (abre no Excel/LibreOffice) |
| Cliques nos cursos | `dados/eventos.csv` |
| Visual / cursos | `frontend/` (`index.html`, `css/`, `js/app.js`) |

> Os dados da Área do aluno são **fictícios**. Não coloque dados reais de alunos sem autorização da faculdade.

## Se algo der errado
- **"O hostapd não conseguiu abrir a rede"** ou **"A placa não deixou criar a rede"** → use o Plano B (USB).
- **"hotspot num canal que não dá para repetir"** → ponha o hotspot do celular em 2,4 GHz e reconecte.
- **"Porta 80 em uso"** → outro programa (apache/nginx) está usando; pare-o ou mude `PORTAL_PORT` em `config.env`.
- **Celular conecta mas não abre o portal** → digite `http://10.77.0.1`. Desligue o "DNS privado" do celular se estiver em "Automático" e persistir.
- **Liberou e não navega** → confira se o notebook ainda tem internet (4G do celular ligado, sinal bom).
- **Ficou sem Wi-Fi no notebook depois de fechar à força** → rode `bash iniciar.sh` e feche com Ctrl+C (ele restaura tudo), ou reinicie o notebook.
- Logs técnicos em `/tmp/portal-eng-software/` (`hostapd.log`, `dnsmasq.log`).

## Como funciona (resumo para o manual técnico)
- **hostapd**: cria a rede Wi-Fi aberta. **dnsmasq**: entrega IP (DHCP) e responde *todo* nome de site com o IP do portal.
- **iptables**: quem não foi liberado só alcança o portal (HTTP é desviado para ele; o resto é bloqueado). Quem clica em
  *Liberar acesso* ganha regras próprias (identificado por IP + MAC): passa a navegar com NAT pelo 4G.
- **Flask** (`servidor/app.py`): serve o site, aplica o limite de 10 e guarda inscrições/eventos em CSV.
- Quando só há **uma placa Wi-Fi**, o script cria uma interface virtual (`ap0`) no **mesmo canal** do hotspot do celular.
