> **Nota (projeto completo):** o Bootstrap agora é servido localmente em `vendor/bootstrap/` (sem CDN) e o backend Flask está em `../servidor/app.py`. Veja o `LEIA-ME.md` na raiz.

# Portal de Acesso — Fatec Jahu

Protótipo front-end reorganizado a partir do HTML enviado. Estrutura separada:

- `index.html`: estrutura semântica e componentes Bootstrap.
- `css/styles.css`: identidade visual, responsividade e estilos próprios.
- `js/app.js`: dados dos cursos, busca/filtro, detalhes, registro de interesse, login de aluno e liberação de acesso.

## Executar para visualizar

Abra `index.html` no navegador. O Bootstrap é carregado por CDN para facilitar a apresentação do protótipo.

## Importante para o portal cativo real

Como a página aparece antes da liberação da internet, dependências externas (CDN, fontes e imagens remotas) podem não carregar. Para implantação, baixe Bootstrap 5.3.3 e coloque os arquivos localmente, ajustando os caminhos no HTML. Os cartões usam ilustrações vetoriais SVG locais em `assets/courses/`, uma por curso, para não depender de imagens remotas no portal cativo.

O JavaScript mantém as rotas do backend Flask esperadas pelo projeto:

- `POST /api/liberar`
- `POST /api/evento`
- `POST /api/inscrever-notificacoes` (novo: e-mail, curso opcional e tópicos escolhidos)
- `POST /api/login`
- `GET /api/avisos`

A tela de sucesso só aparece quando `/api/liberar` responde com sucesso. O layout pode ser demonstrado localmente, mas login, avisos, registro de eventos e liberação real dependem do backend.

## Dados dos cursos

Os cursos e resumos foram organizados a partir do arquivo fornecido e das páginas públicas da Fatec Jahu. Períodos e duração que não estavam claramente confirmados foram marcados como “Consultar site oficial”. A grade curricular e os horários não foram inventados: a janela de detalhes direciona para a página oficial do curso. Revise todos os dados com a faculdade antes de publicar.


## Cadastro de notificações por e-mail

A interface inclui cadastro geral de novidades e cadastro de interesse em um curso. Ambos enviam `POST /api/inscrever-notificacoes` com `email`, `topicos`, `origem` e, quando aplicável, `curso`. O front-end não salva nem envia e-mails sozinho: o backend Flask precisa implementar essa rota, validar o e-mail, armazenar consentimento e preferências, evitar inscrições duplicadas e fornecer uma forma de cancelamento. Até a rota existir e responder `{ "ok": true }`, a interface informa que o cadastro não foi concluído.

Tópicos enviados: `vestibular`, `inicio_aulas`, `eventos_cursos`, `curso`, `eventos`.
