play_board = [['', '', ''], ['', '', ''], ['', '', '']]
is_tie = False
previous_symbol = False

def print_board(play_board):
    for each_list in play_board:
        print(each_list)

def players_moves(board, player_symbol, player_move):
    if player_move <= 3:
        if board[0][player_move - 1] != '':
            return False
        board[0][player_move - 1] = player_symbol
    elif player_move > 3 and player_move <= 6:
        if board[1][player_move - 4] != '':
            return False
        board[1][player_move - 4] = player_symbol
    else:
        if board[2][player_move - 7] != '':
            return False
        board[2][player_move - 7] = player_symbol
    return True

def win(board, play_symbol):
    for each_row in board:
        if len(set(each_row)) == 1 and play_symbol == list(set(each_row))[0]:
            return True
    for count in range(0, 3):
        if board[0][count] == board[1][count] == board[2][count] == play_symbol:
            return True
    if board[0][0] == board[1][1] == board[2][2] == play_symbol or (board[0][2] == board[1][1] == board[2][0] == play_symbol):
        return True
    return False

def tie(board):
    count = 0
    for each_row in board:
        if '' in each_row:
            count += 1
    if count == len(board):
        return False
    return True

while True:
    current_symbol = input('Please enter your symbol')
    if current_symbol not in ['X', 'O']:
        print('Symbol must be X or O')
        continue
    move = input('please enter your move and the file must be between 1 - 9')
    try:
        if int(move):
            move = int(move)
        check_move_done = players_moves(play_board, current_symbol, move)
        if not check_move_done:
            print("Please enter another place as this place is not empty")
            continue
        if previous_symbol and previous_symbol == current_symbol:
            print('The other player must play')
            continue
        else:
            previous_symbol = current_symbol
        print_board(play_board)
        if win(play_board, current_symbol):
            print("This play with symbol "+ current_symbol + " won !")
            break
        if tie(play_board):
            print("The game ended and no player win")
    except:
        print('Wrong move value, please enter your move and the file must be between 1 - 9 ')