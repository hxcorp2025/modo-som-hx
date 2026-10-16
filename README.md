# Modo Som HX

Equalização de som por saída (fone, caixa, monitor), com perfis prontos: **Warzone** (competitivo), **Meet** (voz), **Música** e **Flat**.
Roda dentro do próprio áudio do Windows, sem atraso extra. Feito pela HX em cima do motor aberto [Equalizer APO](https://sourceforge.net/projects/equalizerapo/).

## Instalar (3 minutos)

1. Abra o **PowerShell como administrador**: menu Iniciar, digite `PowerShell`, botão direito, **Executar como administrador**.
2. Cole este comando e dê Enter:

   ```powershell
   irm https://raw.githubusercontent.com/hxcorp2025/modo-som-hx/main/instalar.ps1 | iex
   ```

3. Vai abrir a janela **Equalizer APO Device Selector**. Na parte de cima (*Playback devices*), marque o **seu fone** e as caixas que você usa. Não marque microfones. Clique **OK**. Se perguntar para reiniciar, responda **Não**.
4. O painel **Modo Som HX** abre sozinho e fica com atalho na área de trabalho.

O som some por 2 segundos durante a ativação e volta. Não precisa reiniciar o PC.

## Usar

- **Saídas de som**: cada linha é um fone ou caixa. A coluna **AGORA** é o perfil que está valendo. As colunas **Modo Jogo** e **Modo Trabalho** dizem o que cada saída usa quando você clica nos botões de cima.
- **Modo Jogo (todas as saídas)** / **Modo Trabalho**: troca tudo de uma vez.
- **Ajuste fino**: escolha o perfil e mexa nos sliders. Muda no mesmo instante no fone. Passe o mouse no nome de cada controle para ver o que ele faz.
- **Tocar som de teste**: toca um som na saída padrão. Troque o perfil e toque de novo para comparar.
- **Equalização ligada**: desmarque para ouvir o som puro em tudo.

Sem painel aberto, por atalho ou automação:

```powershell
C:\Users\SEU_USUARIO\ModoSom\ModoSom.cmd jogo       # perfis de jogo em todas as saídas
C:\Users\SEU_USUARIO\ModoSom\ModoSom.cmd trabalho   # perfis de trabalho
```

## O perfil Warzone, em uma frase

Corta o grave abaixo de 90 Hz e o ronco de explosão (que mascaram passo), e levanta a faixa onde passo e recarga vivem (2,5 a 6,5 kHz). Dentro do jogo, deixe **Mix de áudio** em *Fones de ouvido*.

## Atualizar

O mesmo comando de instalação atualiza o painel e **mantém** as suas escolhas e os seus ajustes de perfil.
Para trocar seus perfis pelos perfis novos do repositório:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hxcorp2025/modo-som-hx/main/instalar.ps1))) -AtualizarPerfis
```

## Desinstalar

1. `C:\Program Files\EqualizerAPO\Uninstall.exe` (remove o motor).
2. Apague a pasta `C:\Users\SEU_USUARIO\ModoSom` e o atalho da área de trabalho.

## O que tem dentro

| Arquivo | Pra quê |
|---|---|
| `instalar.ps1` | instalador de um comando (baixa tudo, instala o motor, cria atalho) |
| `ModoSom.ps1` | o painel e o modo sem painel (`jogo`, `trabalho`, `-Gerar`) |
| `ModoSom.cmd` | atalho de linha de comando |
| `perfis.json` | os perfis (frequências, ganhos). É o que vale a pena compartilhar |
| `estado.json` | suas escolhas por saída (gerado no seu PC, não vai pro repositório) |

## Licença

Código do Modo Som HX: MIT. O motor Equalizer APO é de Jonas Thedering, licença GPLv2; o instalador original e o código-fonte estão em [sourceforge.net/projects/equalizerapo](https://sourceforge.net/projects/equalizerapo/files/1.4.2/). A cópia do instalador na aba *Releases* deste repositório existe só porque o SourceForge bloqueia download automático; o arquivo é idêntico ao original (SHA-256 `7403BE74…55AFA`, conferido pelo instalador).
