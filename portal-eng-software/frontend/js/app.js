/* Portal Fatec Jahu
   Front-end organizado. As rotas /api/* preservam a integração esperada com o Flask.
   Confirme os dados de cursos, horários e grades com a instituição antes da publicação. */
const OFFICIAL = 'https://fatecjahu.edu.br/';
const COURSES = [
 {id:'cn',name:'Construção Naval',area:'naval',areaLabel:'Área naval',period:'Diurno',duration:'3 anos · 6 semestres',icon:'⚓',art:'CONSTRUÇÃO NAVAL',color:'#173b4b',profile:'Forma tecnólogos para planejar, supervisionar e fiscalizar processos de construção, reparo e manutenção naval. O material de origem destaca as atividades práticas no Estaleiro Escola e possibilidades de atuação em estaleiros, vistorias e transporte marítimo.',contact:'Coordenação: Prof. Dr. Hilton Aparecido Garcia · (14) 3622-8280, ramal 222',url:'https://fatecjahu.edu.br/construcao-naval/'},
 {id:'dsm',name:'Desenvolvimento de Software Multiplataforma',area:'tech',areaLabel:'Tecnologia',period:'Matutino',duration:'3 anos · 6 semestres',icon:'⌘',art:'SOFTWARE & DADOS',color:'#3b285a',profile:'Forma profissionais para projetar, desenvolver e testar software para múltiplas plataformas, aplicações em nuvem e Internet das Coisas. A formação envolve programação, bancos de dados, engenharia de software, segurança da informação e inteligência artificial.',contact:'Coordenação: Prof. Me. Célio Sormani Junior · (14) 3622-8280, ramal 210',url:'https://fatecjahu.edu.br/desenvolvimento-de-software-multiplataforma/'},
 {id:'gpi',name:'Gestão da Produção Industrial',area:'gestao',areaLabel:'Gestão e negócios',period:'Noturno',duration:'3 anos · 6 semestres',icon:'▥',art:'PRODUÇÃO & PROCESSOS',color:'#6a3028',profile:'Forma tecnólogos para atuar na inovação e melhoria de processos produtivos, com foco em produtividade, qualidade e sustentabilidade. O curso trabalha projetos interdisciplinares e prepara para organizações industriais, comerciais e de serviços.',contact:'Coordenação: Prof. Esp. Alessandro Lameiro Brancão · (14) 3622-8280, ramal 224',url:'https://fatecjahu.edu.br/gestao-da-producao-industrial/'},
 {id:'gti',name:'Gestão da Tecnologia da Informação',area:'tech',areaLabel:'Tecnologia',period:'Consultar site oficial',duration:'Consultar site oficial',icon:'⌁',art:'GESTÃO DE TI',color:'#253a64',profile:'Forma profissionais para administrar a infraestrutura física e lógica de ambientes de tecnologia da informação, gerenciar equipes técnicas, implantar rotinas e acompanhar serviços de sistemas operacionais e bancos de dados.',contact:'Coordenação: Profa. Esp. Vera Maria Ferro Merlini · (14) 3622-8280, ramal 201',url:'https://fatecjahu.edu.br/gestao-da-tecnologia-da-informacao/'},
 {id:'ge',name:'Gestão Empresarial (EAD)',area:'gestao',areaLabel:'Gestão e negócios',period:'EAD',duration:'Consultar site oficial',icon:'▤',art:'NEGÓCIOS & ESTRATÉGIA',color:'#5b3b63',profile:'Curso oferecido na modalidade a distância. Consulte a página oficial para conhecer o perfil profissional, a organização das disciplinas e as condições atuais de oferta.',contact:'Consulte a Diretoria Acadêmica: (14) 3622-8280',url:'https://fatecjahu.edu.br/gestao-empresarial-ead/'},
 {id:'log',name:'Logística',area:'gestao',areaLabel:'Gestão e negócios',period:'Consultar site oficial',duration:'Consultar site oficial',icon:'⇄',art:'LOGÍSTICA & FLUXOS',color:'#345443',profile:'Forma profissionais para planejar e coordenar a movimentação de materiais e informações, armazenagem, distribuição, fornecedores, estoques e custos de transporte em diferentes modais.',contact:'Coordenação: Prof. Me. Flávio Luís Grava Scalco · (14) 3622-8280, ramal 232',url:'https://fatecjahu.edu.br/logistica/'},
 {id:'marh',name:'Meio Ambiente e Recursos Hídricos',area:'ambiental',areaLabel:'Meio ambiente',period:'Noturno',duration:'3 anos · 6 semestres',icon:'♧',art:'ÁGUA & SUSTENTABILIDADE',color:'#24645c',profile:'Forma tecnólogos para planejar e gerenciar aspectos ambientais, identificar e solucionar problemas e realizar a gestão responsável dos recursos hídricos, incluindo recuperação de áreas degradadas, rios e bacias hidrográficas.',contact:'Coordenação: Profª. Drª. Marina Carboni · (14) 3622-8280, ramal 234',url:'https://fatecjahu.edu.br/meio-ambiente-e-recursos-hidricos/'},
 {id:'si',name:'Sistemas para Internet',area:'tech',areaLabel:'Tecnologia',period:'Consultar situação atual',duration:'Consultar site oficial',icon:'⌘',art:'WEB & EXPERIÊNCIAS DIGITAIS',color:'#4a3b76',profile:'O material enviado descreve a formação de profissionais para desenvolver programas, interfaces e aplicativos para internet e intranet. A situação atual de oferta deve ser confirmada no site oficial antes de divulgar inscrições.',contact:'Coordenação: Prof. Esp. Hélio Luis da Silva Rodrigues · (14) 3622-8280, ramal 242',url:'https://fatecjahu.edu.br/sistemas-para-internet/'},
 {id:'sn',name:'Sistemas de Navegação Fluvial',area:'naval',areaLabel:'Área naval',period:'Consultar site oficial',duration:'Consultar site oficial',icon:'≈',art:'NAVEGAÇÃO FLUVIAL',color:'#28546b',profile:'Forma tecnólogos para planejar e fiscalizar sistemas de transporte aquaviário, gerenciar frotas, portos e terminais e realizar vistorias e inspeções navais. O material de origem destaca laboratórios do Estaleiro Escola e simuladores.',contact:'Coordenação: Profa. Rosa Maria Padroni · (14) 3622-8280, ramais 222/201',url:'https://fatecjahu.edu.br/sistemas-navais/'},
 {id:'en',name:'Engenharia Naval',area:'naval',areaLabel:'Área naval',period:'Diurno',duration:'5 anos',icon:'⚓',art:'ENGENHARIA NAVAL',color:'#183e55',profile:'Bacharelado voltado a projeto, estruturas, máquinas, hidrodinâmica, materiais e tecnologias de construção naval, além de transporte hidroviário, logística e organização portuária. O site oficial informa primeira turma de ingresso em 2027.',contact:'Consulte a página oficial do curso para contatos e informações atualizadas.',url:'https://fatecjahu.edu.br/engenharia-naval/'},
 {id:'ep',name:'Engenharia de Produção',area:'gestao',areaLabel:'Gestão e negócios',period:'Noturno',duration:'5 anos',icon:'▥',art:'ENGENHARIA DE PRODUÇÃO',color:'#67402b',profile:'Bacharelado para planejar, coordenar e otimizar sistemas produtivos e logísticos, com foco em melhoria contínua, qualidade, inovação e sustentabilidade. O site oficial informa primeira turma de ingresso em 2027.',contact:'Consulte a página oficial do curso para contatos e informações atualizadas.',url:'https://fatecjahu.edu.br/engenharia-de-producao/'}
];
const list = document.querySelector('#course-list');
const search = document.querySelector('#course-search');
const areaFilter = document.querySelector('#area-filter');
const count = document.querySelector('#course-count');
const empty = document.querySelector('#empty-state');
let currentCourse = null;
const interests = new Set();
const modalElement = document.querySelector('#course-modal');
const courseModal = window.bootstrap ? new bootstrap.Modal(modalElement) : null;
const successElement = document.querySelector('#success-modal');
const successModal = window.bootstrap ? new bootstrap.Modal(successElement) : null;

function renderCourses(){
 const term = search.value.trim().toLocaleLowerCase('pt-BR');
 const area = areaFilter.value;
 const filtered = COURSES.filter(c => c.name.toLocaleLowerCase('pt-BR').includes(term) && (area === 'all' || c.area === area));
 list.replaceChildren();
 count.textContent = `${filtered.length} ${filtered.length === 1 ? 'curso' : 'cursos'}`;
 empty.classList.toggle('d-none', filtered.length !== 0);
 filtered.forEach(c => {
  const col = document.createElement('div'); col.className = 'col-12 col-sm-6 col-lg-4';
  const button = document.createElement('button'); button.type = 'button'; button.className = 'course-card'; button.setAttribute('aria-label', `Ver informações de ${c.name}`);
  const art = document.createElement('div'); art.className = 'card-art'; art.style.setProperty('--art-bg', c.color);
  const image = document.createElement('img'); image.className = 'course-art-image'; image.src = `assets/courses/${c.id}.svg`; image.alt = `Ilustração de referência: ${c.name}`; image.loading = 'lazy';
  const word = document.createElement('span'); word.className = 'art-word'; word.textContent = c.art;
  art.append(image, word);
  const body = document.createElement('div'); body.className = 'card-body-custom';
  const tags = document.createElement('div'); tags.className = 'card-tags';
  const tag = document.createElement('span'); tag.className = 'course-tag'; tag.textContent = c.areaLabel;
  const id = document.createElement('span'); id.className = 'area-tag'; id.textContent = 'Fatec Jahu'; tags.append(tag,id);
  const title = document.createElement('h3'); title.textContent = c.name;
  const meta = document.createElement('div'); meta.className = 'course-meta';
  [c.period,c.duration].filter(Boolean).forEach(t => { const s = document.createElement('span'); s.textContent = t; meta.append(s); });
  const link = document.createElement('div'); link.className = 'card-link'; const label = document.createElement('span'); label.textContent = 'Ver informações'; const arrow = document.createElement('span'); arrow.textContent = '→'; link.append(label,arrow);
  body.append(tags,title,meta,link); button.append(art,body); button.addEventListener('click',()=>openCourse(c.id)); col.append(button); list.append(col);
 });
}
function openCourse(id){
 const c = COURSES.find(item=>item.id===id); if(!c) return; currentCourse = c; registrar('ver_curso',c.id);
 document.querySelector('#modal-course-name').textContent = c.name;
 document.querySelector('#modal-area').textContent = c.areaLabel;
 document.querySelector('#modal-profile').textContent = c.profile;
 document.querySelector('#modal-contact').textContent = c.contact;
 const meta = document.querySelector('#modal-meta'); meta.replaceChildren();
 [['Período',c.period],['Duração',c.duration]].forEach(([label,value])=>{const item=document.createElement('span');item.textContent=`${label}: ${value}`;meta.append(item)});
 document.querySelector('#official-course-link').href = c.url || OFFICIAL;
 const interestButton = document.querySelector('#btn-interest'); interestButton.disabled = interests.has(c.id); interestButton.textContent = interests.has(c.id) ? 'Interesse registrado ✓' : 'Tenho interesse neste curso';
 if(courseModal) courseModal.show(); else window.open(c.url || OFFICIAL,'_blank','noopener');
}
function registrar(tipo,curso){fetch('/api/evento',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tipo,curso}),keepalive:true}).catch(()=>{});}
search.addEventListener('input',renderCourses); areaFilter.addEventListener('change',renderCourses);
const interestModalElement = document.querySelector('#interest-modal');
const interestModal = window.bootstrap ? new bootstrap.Modal(interestModalElement) : null;
const interestForm = document.querySelector('#interest-form');
const interestMsg = document.querySelector('#interest-msg');
document.querySelector('#btn-interest').addEventListener('click',()=>{
 if(!currentCourse||interests.has(currentCourse.id))return;
 document.querySelector('#interest-course-name').textContent = currentCourse.name;
 document.querySelector('#interest-course-id').value = currentCourse.id;
 interestMsg.textContent = '';
 if(interestModal) interestModal.show(); else interestModalElement.classList.add('show');
});
interestForm.addEventListener('submit', async event=>{
 event.preventDefault();
 const submit=interestForm.querySelector('button[type="submit"]');
 const email=document.querySelector('#interest-email').value.trim();
 const topics=[...interestForm.querySelectorAll('input[name="topics"]:checked')].map(input=>input.value);
 if(!currentCourse || !email) return;
 submit.disabled=true; submit.textContent='Enviando…'; interestMsg.className='form-feedback'; interestMsg.textContent='';
 try {
  const response=await fetch('/api/inscrever-notificacoes',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,curso:currentCourse.id,topicos:topics,origem:'interesse_curso',consentimento:true})});
  const data=await response.json();
  if(!response.ok || !data.ok) throw new Error(data.erro || 'Não foi possível registrar. Tente novamente.');
  interests.add(currentCourse.id); registrar('interesse',currentCourse.id);
  const b=document.querySelector('#btn-interest'); b.disabled=true; b.textContent='Interesse registrado ✓';
  interestMsg.className='form-feedback success'; interestMsg.textContent=data.mensagem || 'Cadastro confirmado! Você receberá avisos conforme as preferências selecionadas.';
  interestForm.reset();
  setTimeout(()=>{if(interestModal) interestModal.hide();},1400);
 } catch(error) {
  interestMsg.className='form-feedback error';
  interestMsg.textContent=error.message==='Failed to fetch'?'O cadastro precisa do endpoint /api/inscrever-notificacoes no servidor. O e-mail ainda não foi registrado.':error.message;
 } finally { submit.disabled=false; submit.textContent='Quero receber avisos'; }
});

const newsletterForm=document.querySelector('#newsletter-form');
newsletterForm.addEventListener('submit',async event=>{
 event.preventDefault();
 const email=document.querySelector('#newsletter-email').value.trim();
 const topics=[...newsletterForm.querySelectorAll('input[name="newsletter-topics"]:checked')].map(input=>input.value);
 const msg=document.querySelector('#newsletter-msg'); const btn=newsletterForm.querySelector('button[type="submit"]');
 msg.className='form-feedback'; msg.textContent=''; btn.disabled=true; btn.textContent='Cadastrando…';
 try {
  const response=await fetch('/api/inscrever-notificacoes',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,topicos:topics,origem:'painel_publico',consentimento:true})});
  const data=await response.json(); if(!response.ok||!data.ok) throw new Error(data.erro||'Não foi possível concluir o cadastro.');
  msg.className='form-feedback success'; msg.textContent=data.mensagem||'Cadastro confirmado!'; newsletterForm.reset();
 } catch(error) { msg.className='form-feedback error'; msg.textContent=error.message==='Failed to fetch'?'O cadastro ainda precisa ser conectado ao servidor. Nenhum e-mail foi salvo.':error.message; }
 finally {btn.disabled=false;btn.textContent='Quero receber novidades';}
});

document.querySelector('#btn-release').addEventListener('click',async()=>{
 const btn=document.querySelector('#btn-release'), msg=document.querySelector('#release-msg');msg.textContent='';btn.disabled=true;btn.textContent='Conectando…';
 try{const response=await fetch('/api/liberar',{method:'POST'});const data=await response.json();if(!response.ok||!data.ok)throw new Error(data.erro||'Não foi possível liberar o acesso. Tente novamente.');if(successModal)successModal.show();else alert('Acesso liberado!');}
 catch(error){msg.textContent=error.message==='Failed to fetch'?'Sem resposta do portal. Confira se está conectado ao Wi-Fi do evento.':error.message;}
 finally{btn.disabled=false;btn.innerHTML='Liberar acesso <span aria-hidden="true">→</span>';}
});

document.querySelector('#student-form').addEventListener('submit',async event=>{
 event.preventDefault();const msg=document.querySelector('#student-msg'),content=document.querySelector('#student-content'),ra=document.querySelector('#ra').value.trim();msg.className='student-msg';msg.textContent='Verificando…';content.replaceChildren();
 try{const response=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ra})});const data=await response.json();if(!response.ok||!data.ok)throw new Error(data.erro||'Não foi possível entrar.');msg.textContent=data.nome?`Olá, ${data.nome}!`:'Bem-vindo!';
  (data.avisos||[]).forEach(a=>{const box=document.createElement('div');box.className='notice';const strong=document.createElement('strong');strong.textContent=a.titulo;const p=document.createElement('div');p.textContent=a.mensagem;box.append(strong,p);content.append(box)});
  if(data.horarios?.length){const table=document.createElement('table');table.className='table table-sm schedule-table';const thead=document.createElement('thead'),tr=document.createElement('tr');['Dia','Horário','Disciplina','Sala'].forEach(label=>{const th=document.createElement('th');th.textContent=label;tr.append(th)});thead.append(tr);const tbody=document.createElement('tbody');const days=['','Segunda','Terça','Quarta','Quinta','Sexta','Sábado'];data.horarios.forEach(h=>{const row=document.createElement('tr');[days[h.dia]||h.dia,`${h.inicio}–${h.fim}`,h.disciplina,h.sala||''].forEach(value=>{const td=document.createElement('td');td.textContent=value;row.append(td)});tbody.append(row)});table.append(thead,tbody);content.append(table)}
 }catch(error){msg.className='student-msg error';msg.textContent=error.message==='Failed to fetch'?'Sem resposta do portal. Verifique a conexão e tente novamente.':error.message;}
});
async function carregarAvisos(){try{const response=await fetch('/api/avisos');if(!response.ok)return;const data=await response.json();const section=document.querySelector('#cursos');(data.avisos||[]).slice(0,3).reverse().forEach(a=>{const notice=document.createElement('div');notice.className='notice mb-2';const title=document.createElement('strong');title.textContent=a.titulo;const message=document.createElement('div');message.textContent=a.mensagem;notice.append(title,message);section.prepend(notice);});}catch(_){/* Avisos indisponíveis não bloqueiam a navegação pública. */}}
renderCourses();carregarAvisos();
